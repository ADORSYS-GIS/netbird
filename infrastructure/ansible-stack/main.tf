module "inventory" {
  source = "../modules/inventory"

  netbird_hosts = var.netbird_hosts
}

module "database" {
  source = "../modules/database"

  database_type = var.database_type
  database_mode = var.database_mode
  enable_ha     = var.enable_ha

  # SQLite
  sqlite_database_path = var.sqlite_database_path

  # PostgreSQL Existing
  existing_postgresql_host     = var.existing_postgresql_host
  existing_postgresql_port     = var.existing_postgresql_port
  existing_postgresql_database = var.existing_postgresql_database
  existing_postgresql_username = var.existing_postgresql_username
  existing_postgresql_password = var.existing_postgresql_password
  existing_postgresql_sslmode  = var.existing_postgresql_sslmode
}

module "keycloak" {
  source = "../modules/keycloak"

  keycloak_url            = var.keycloak_url
  keycloak_admin_username = var.keycloak_admin_username
  keycloak_admin_password = var.keycloak_admin_password
  realm_name              = var.realm_name
  use_existing_realm      = var.keycloak_use_existing_realm
  netbird_domain          = var.netbird_domain
  netbird_admin_email     = var.netbird_admin_email
  netbird_admin_password  = var.netbird_admin_password
}

# Automated Secret Generation
# NOTE: Keepers prevent regeneration on re-applies (critical for HA)
# If you need to regenerate, change the version number in keepers
resource "random_password" "relay_auth_secret" {
  length  = 32
  special = true

  keepers = {
    version = "1.0"
  }
}

resource "random_id" "netbird_encryption_key" {
  byte_length = 32

  keepers = {
    version = "1.0"
  }
}

resource "random_password" "coturn_password" {
  length  = 32
  special = true

  keepers = {
    version = "1.0"
  }
}

locals {
  inventory_path = "${path.module}/../../configuration/ansible/inventory/terraform_inventory.yaml"
  inventory_content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    netbird_domain         = var.netbird_domain
    netbird_version        = var.netbird_version
    coturn_version         = var.coturn_version
    netbird_log_level      = var.netbird_log_level
    caddy_version          = var.caddy_version
    haproxy_version        = var.haproxy_version
    proxy_type             = var.proxy_type
    acme_provider          = var.acme_provider
    acme_email             = var.acme_email
    docker_compose_version = var.docker_compose_version

    # Database
    database_type        = module.database.database_type
    database_engine      = module.database.database_engine
    database_dsn         = module.database.database_dsn
    database_endpoint    = module.database.database_endpoint
    database_port        = module.database.database_port
    database_name        = module.database.database_name
    database_username    = module.database.database_username
    database_password    = module.database.database_password
    database_sslmode     = module.database.database_sslmode
    sqlite_database_path = var.sqlite_database_path

    # Keycloak
    keycloak_url                   = var.keycloak_url
    keycloak_realm                 = module.keycloak.realm_name
    keycloak_client_id             = module.keycloak.client_id
    keycloak_backend_client_id     = module.keycloak.backend_client_id
    keycloak_backend_client_secret = module.keycloak.backend_client_secret
    keycloak_oidc_endpoint         = module.keycloak.oidc_config_endpoint

    relay_auth_secret      = var.relay_auth_secret != "" ? var.relay_auth_secret : random_password.relay_auth_secret.result
    netbird_encryption_key = var.netbird_encryption_key != "" ? var.netbird_encryption_key : random_id.netbird_encryption_key.b64_std
    coturn_password        = random_password.coturn_password.result
    coturn_port            = 3478
    coturn_min_port        = 49152
    coturn_max_port        = 65535
    coturn_realm           = var.netbird_domain

    # HA Configuration
    enable_clustering              = var.enable_clustering
    netbird_cluster_port           = var.netbird_cluster_port
    enable_pgbouncer               = var.enable_pgbouncer
    pgbouncer_listen_port          = var.pgbouncer_listen_port
    pgbouncer_min_pool_size        = var.pgbouncer_min_pool_size
    pgbouncer_default_pool_size    = var.pgbouncer_default_pool_size
    pgbouncer_reserve_pool_size    = var.pgbouncer_reserve_pool_size
    pgbouncer_reserve_pool_timeout = var.pgbouncer_reserve_pool_timeout
    pgbouncer_pool_mode            = var.pgbouncer_pool_mode

    # HAProxy Health Check Configuration
    haproxy_health_check_interval = var.haproxy_health_check_interval
    haproxy_health_check_timeout  = var.haproxy_health_check_timeout
    haproxy_health_check_fall     = var.haproxy_health_check_fall
    haproxy_health_check_rise     = var.haproxy_health_check_rise
    haproxy_stick_table_size      = var.haproxy_stick_table_size
    haproxy_stick_table_expire    = var.haproxy_stick_table_expire

    # Compute addresses for management.json
    relay_addresses = [for node in module.inventory.relay_nodes : "rels://${node.public_ip}:33080"]
    stun_addresses  = [for node in module.inventory.management_nodes : "stun:${node.public_ip}:3478"]

    management_nodes    = module.inventory.management_nodes
    reverse_proxy_nodes = module.inventory.reverse_proxy_nodes
    relay_nodes         = module.inventory.relay_nodes

    ssh_private_key_path = var.ssh_private_key_path
  })
}

# Automate Ansible Deployment and Cleanup
resource "terraform_data" "ansible_provisioning" {
  # We store the inventory content and path in the state so the destroy provisioner can recreate it if needed
  input = {
    content = local.inventory_content
    path    = local.inventory_path
  }

  triggers_replace = [
    local.inventory_content,
    module.database.database_dsn,
    module.keycloak.backend_client_secret,
    sha256(file("${path.module}/../../configuration/ansible/roles/netbird-management/templates/management.json.j2")),
    sha256(file("${path.module}/../../configuration/ansible/roles/reverse-proxy/templates/Caddyfile.j2")),
    sha256(file("${path.module}/../../configuration/ansible/roles/netbird-dashboard/tasks/main.yml"))
  ]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p $(dirname ${local.inventory_path})
      echo "${base64encode(local.inventory_content)}" | base64 -d > ${local.inventory_path}
      chmod 600 ${local.inventory_path}
      cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml || exit 1
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      mkdir -p $(dirname ${self.input.path})
      echo "${base64encode(self.input.content)}" | base64 -d > ${self.input.path}
      chmod 600 ${self.input.path}
      cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/cleanup.yml || echo 'Cleanup failed, proceeding anyway'
      rm -f ${self.input.path}
    EOT
  }
}
