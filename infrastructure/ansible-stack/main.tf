module "inventory" {
  source = "../modules/inventory"

  cloud_provider = var.cloud_provider

  # AWS
  aws_region      = var.aws_region
  aws_tag_filters = var.aws_tag_filters

  # GCP
  gcp_project       = var.gcp_project
  gcp_region        = var.gcp_region
  gcp_label_filters = var.gcp_label_filters

  # Azure
  azure_resource_group = var.azure_resource_group
  azure_tag_filters    = var.azure_tag_filters

  # Manual hosts
  manual_hosts = var.manual_hosts
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

  # AWS-specific
  vpc_id                      = module.inventory.vpc_id
  database_subnet_ids         = module.inventory.subnet_ids
  database_security_group_ids = []
  tags                        = { Environment = var.environment }

  # PostgreSQL Existing
  existing_postgresql_host     = var.existing_postgresql_host
  existing_postgresql_port     = var.existing_postgresql_port
  existing_postgresql_database = var.existing_postgresql_database
  existing_postgresql_username = var.existing_postgresql_username
  existing_postgresql_password = var.existing_postgresql_password
  existing_postgresql_sslmode  = var.existing_postgresql_sslmode

  # MySQL Existing
  existing_mysql_host     = var.existing_mysql_host
  existing_mysql_port     = var.existing_mysql_port
  existing_mysql_database = var.existing_mysql_database
  existing_mysql_username = var.existing_mysql_username
  existing_mysql_password = var.existing_mysql_password
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

resource "random_password" "coturn_password" {
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
    sqlite_database_path = var.sqlite_database_path

    # Keycloak
    keycloak_url           = var.keycloak_url
    keycloak_realm         = module.keycloak.realm_name
    keycloak_client_id     = module.keycloak.client_id
    keycloak_client_secret = module.keycloak.client_secret
    keycloak_oidc_endpoint = module.keycloak.oidc_config_endpoint

    relay_auth_secret      = var.relay_auth_secret != "" ? var.relay_auth_secret : random_password.relay_auth_secret.result
    coturn_password        = var.coturn_password != "" ? var.coturn_password : random_password.coturn_password.result
    netbird_encryption_key = var.netbird_encryption_key != "" ? var.netbird_encryption_key : random_id.netbird_encryption_key.b64_std

    management_nodes    = module.inventory.management_nodes
    reverse_proxy_nodes = module.inventory.reverse_proxy_nodes
    relay_nodes         = module.inventory.relay_nodes

    ssh_user             = var.ssh_user
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
    module.keycloak.client_secret
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
