module "inventory" {
  source = "../modules/inventory"

  netbird_hosts = var.netbird_hosts
}

module "database" {
  source = "../modules/database"

  database_type = var.database_type
  database_mode = var.database_mode
  enable_ha     = var.enable_ha

  sqlite_database_path = var.sqlite_database_path

  existing_postgresql_host            = var.existing_postgresql_host
  existing_postgresql_port            = var.existing_postgresql_port
  existing_postgresql_database        = var.existing_postgresql_database
  existing_postgresql_username        = var.existing_postgresql_username
  existing_postgresql_password        = var.existing_postgresql_password
  existing_postgresql_sslmode         = var.existing_postgresql_sslmode
  existing_postgresql_channel_binding = var.existing_postgresql_channel_binding
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

# Automated secret generation with keepers to prevent regeneration
resource "random_password" "relay_auth_secret" {
  length  = 32
  special = true

  keepers = {
    version = "1.0"
  }
}

resource "random_password" "netbird_encryption_key" {
  length  = 32
  special = false

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

resource "random_password" "haproxy_stats_password" {
  length  = 24
  special = true

  keepers = {kubectl get pods -n netbird
kubectl get pods -A | grep netbird

    version = "1.0"
  }
}

# Read ACME thumbprint from file if it exists (persisted by Ansible)
data "local_file" "acme_thumbprint" {
  count    = var.acme_account_thumbprint == "" && fileexists("${path.module}/.acme_thumbprint") ? 1 : 0
  filename = "${path.module}/.acme_thumbprint"
}

locals {
  # Use thumbprint from: 1) tfvars, 2) persisted file, 3) empty (will be auto-generated)
  final_acme_thumbprint = var.acme_account_thumbprint != "" ? var.acme_account_thumbprint : (
    length(data.local_file.acme_thumbprint) > 0 ? trimspace(data.local_file.acme_thumbprint[0].content) : ""
  )

  inventory_path = "${path.module}/../../configuration/ansible/inventory/terraform_inventory.yaml"

  inventory_content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    netbird_domain          = var.netbird_domain
    netbird_version         = var.netbird_version
    coturn_version          = var.coturn_version
    netbird_log_level       = var.netbird_log_level
    netbird_admin_email     = var.netbird_admin_email
    netbird_admin_password  = var.netbird_admin_password
    caddy_version           = var.caddy_version
    haproxy_version         = var.haproxy_version
    proxy_type              = var.proxy_type
    acme_provider           = var.acme_provider
    acme_email              = var.acme_email
    acme_account_thumbprint = local.final_acme_thumbprint
    docker_compose_version  = var.docker_compose_version

    database_type            = module.database.database_type
    database_engine          = module.database.database_engine
    database_dsn             = module.database.database_dsn
    database_endpoint        = module.database.database_endpoint
    database_port            = module.database.database_port
    database_name            = module.database.database_name
    database_username        = module.database.database_username
    database_password        = module.database.database_password
    database_sslmode         = module.database.database_sslmode
    database_channel_binding = module.database.database_channel_binding
    sqlite_database_path     = var.sqlite_database_path

    keycloak_url                   = var.keycloak_url
    keycloak_realm                 = module.keycloak.realm_name
    keycloak_client_id             = module.keycloak.client_id
    keycloak_backend_client_id     = module.keycloak.backend_client_id
    keycloak_backend_client_secret = module.keycloak.backend_client_secret
    keycloak_oidc_endpoint         = module.keycloak.oidc_config_endpoint

    relay_auth_secret      = var.relay_auth_secret != "" ? var.relay_auth_secret : random_password.relay_auth_secret.result
    netbird_encryption_key = var.netbird_encryption_key != "" ? var.netbird_encryption_key : random_password.netbird_encryption_key.result
    coturn_password        = random_password.coturn_password.result
    coturn_port            = var.coturn_port
    coturn_min_port        = var.coturn_min_port
    coturn_max_port        = var.coturn_max_port
    coturn_realm           = var.netbird_domain

    enable_clustering              = var.enable_clustering
    netbird_cluster_port           = var.netbird_cluster_port
    enable_pgbouncer               = var.enable_pgbouncer
    pgbouncer_listen_port          = var.pgbouncer_listen_port
    pgbouncer_min_pool_size        = var.pgbouncer_min_pool_size
    pgbouncer_default_pool_size    = var.pgbouncer_default_pool_size
    pgbouncer_reserve_pool_size    = var.pgbouncer_reserve_pool_size
    pgbouncer_reserve_pool_timeout = var.pgbouncer_reserve_pool_timeout
    pgbouncer_pool_mode            = var.pgbouncer_pool_mode
    pgbouncer_server_lifetime      = var.pgbouncer_server_lifetime
    pgbouncer_server_idle_timeout  = var.pgbouncer_server_idle_timeout
    pgbouncer_query_timeout        = var.pgbouncer_query_timeout
    pgbouncer_query_wait_timeout   = var.pgbouncer_query_wait_timeout
    pgbouncer_client_idle_timeout  = var.pgbouncer_client_idle_timeout
    pgbouncer_max_client_conn      = var.pgbouncer_max_client_conn
    pgbouncer_max_db_connections   = var.pgbouncer_max_db_connections
    pgbouncer_max_user_connections = var.pgbouncer_max_user_connections
    pgbouncer_stats_period         = var.pgbouncer_stats_period
    pgbouncer_health_check_period  = var.pgbouncer_health_check_period
    pgbouncer_health_check_timeout = var.pgbouncer_health_check_timeout

    haproxy_health_check_interval = var.haproxy_health_check_interval
    haproxy_health_check_timeout  = var.haproxy_health_check_timeout
    haproxy_health_check_fall     = var.haproxy_health_check_fall
    haproxy_health_check_rise     = var.haproxy_health_check_rise
    haproxy_stick_table_size      = var.haproxy_stick_table_size
    haproxy_stick_table_expire    = var.haproxy_stick_table_expire
    haproxy_stats_password        = var.haproxy_stats_password != "" ? var.haproxy_stats_password : random_password.haproxy_stats_password.result

    relay_addresses = [for node in module.inventory.relay_nodes : "rels://${node.public_ip}:33080"]
    stun_addresses  = [for node in module.inventory.management_nodes : "stun:${node.public_ip}:3478"]

    management_nodes    = module.inventory.management_nodes
    reverse_proxy_nodes = module.inventory.reverse_proxy_nodes
    relay_nodes         = module.inventory.relay_nodes

    ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  })
}

# Write inventory file
resource "local_file" "ansible_inventory" {
  content         = local.inventory_content
  filename        = local.inventory_path
  file_permission = "0600"
}

# Trigger Ansible deployment when inventory changes
resource "null_resource" "ansible_deployment" {
  count = var.auto_deploy ? 1 : 0

  triggers = {
    inventory_version = local_file.ansible_inventory.id
  }

  provisioner "local-exec" {
    command     = "ansible-playbook -i ${local.inventory_path} playbooks/site.yml"
    working_dir = "${path.module}/../../configuration/ansible"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }

  depends_on = [local_file.ansible_inventory]
}

# Cleanup on destroy
resource "null_resource" "ansible_cleanup" {
  count = var.auto_deploy ? 1 : 0

  provisioner "local-exec" {
    when        = destroy
    command     = "ansible-playbook -i inventory/terraform_inventory.yaml playbooks/cleanup.yml || true"
    working_dir = "${path.module}/../../configuration/ansible"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}
