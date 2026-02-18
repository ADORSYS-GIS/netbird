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

  # PostgreSQL Create
  cloud_provider                   = var.cloud_provider
  postgresql_instance_class        = var.postgresql_instance_class
  postgresql_storage_gb            = var.postgresql_storage_gb
  postgresql_database_name         = var.postgresql_database_name
  postgresql_username              = var.postgresql_username
  postgresql_password              = var.postgresql_password
  postgresql_multi_az              = var.postgresql_multi_az
  postgresql_backup_retention_days = var.postgresql_backup_retention_days

  # Subnets/VPC (if needed for creation)
  vpc_id                      = ""
  database_subnet_ids         = []
  database_security_group_ids = []
  tags                        = { Environment = var.environment }

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
resource "random_password" "relay_auth_secret" {
  length  = 32
  special = true
}

resource "random_id" "netbird_encryption_key" {
  byte_length = 32
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    netbird_domain    = var.netbird_domain
    netbird_version   = var.netbird_version
    netbird_log_level = var.netbird_log_level

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
    netbird_log_level      = var.netbird_log_level
    netbird_version        = var.netbird_version
    caddy_version          = var.caddy_version
    docker_compose_version = var.docker_compose_version


    # Compute relay addresses list for management.json (rels://IP:443 format)
    relay_addresses = [for node in module.inventory.relay_nodes : "rels://${node.public_ip}:443"]

    management_nodes    = module.inventory.management_nodes
    reverse_proxy_nodes = module.inventory.reverse_proxy_nodes
    relay_nodes         = module.inventory.relay_nodes

    ssh_private_key_path = var.ssh_private_key_path
  })
  filename        = "${path.module}/../../configuration/ansible/inventory/terraform_inventory.yaml"
  file_permission = "0600"
}

# Automate Ansible Deployment and Cleanup
resource "terraform_data" "ansible_provisioning" {
  triggers_replace = [
    local_file.ansible_inventory.content,
    module.database.database_dsn,
    module.keycloak.backend_client_secret
  ]

  provisioner "local-exec" {
    command = "cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/cleanup.yml"
  }

  depends_on = [local_file.ansible_inventory]
}
