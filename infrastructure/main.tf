module "inventory_aws" {
  source      = "./modules/inventory-aws"
  region      = var.aws_region
  tag_filters = var.aws_tag_filters
  environment = var.environment
}

module "inventory_gcp" {
  source        = "./modules/inventory-gcp"
  project       = var.gcp_project
  region        = var.gcp_region
  label_filters = var.gcp_label_filters
}

module "inventory_azure" {
  source              = "./modules/inventory-azure"
  resource_group_name = var.azure_resource_group
  tag_filters         = var.azure_tag_filters
}

module "network_security" {
  source              = "./modules/network-security"
  cloud_provider      = var.cloud_provider
  environment         = var.environment
  vpc_name            = var.vpc_name
  network_name        = var.gcp_network_name
  resource_group_name = var.azure_resource_group
  vnet_name           = var.azure_vnet_name
  location            = var.azure_location
  admin_cidr_blocks   = var.admin_cidr_blocks
}

module "inventory_manual" {
  source       = "./modules/inventory-manual"
  manual_hosts = var.manual_hosts
}

# Unified Database Module
module "database" {
  source = "./modules/database-backend"

  database_type = var.database_type
  database_mode = var.database_mode
  enable_ha     = var.enable_ha

  # SQLite
  sqlite_database_path = var.sqlite_database_path

  # PostgreSQL Create
  cloud_provider                     = var.postgresql_cloud_provider
  postgresql_instance_class          = var.postgresql_instance_class
  postgresql_storage_gb              = var.postgresql_storage_gb
  postgresql_database_name           = var.postgresql_database_name
  postgresql_username                = var.postgresql_username
  postgresql_password                = var.postgresql_password
  postgresql_multi_az                = var.postgresql_multi_az
  postgresql_backup_retention_days   = var.postgresql_backup_retention_days
  
  # AWS Specifics (Only pass if using AWS to prevent dependency errors)
  vpc_id                             = var.cloud_provider == "aws" ? module.inventory_aws.vpc_id : null
  database_subnet_ids                = var.cloud_provider == "aws" ? module.inventory_aws.subnet_ids : []
  database_security_group_ids        = [module.network_security.security_group_id]
  tags                               = { Environment = var.environment }

  # PostgreSQL Existing
  existing_postgresql_host           = var.existing_postgresql_host
  existing_postgresql_port           = var.existing_postgresql_port
  existing_postgresql_database       = var.existing_postgresql_database
  existing_postgresql_username       = var.existing_postgresql_username
  existing_postgresql_password       = var.existing_postgresql_password
  existing_postgresql_sslmode        = var.existing_postgresql_sslmode

  # MySQL Existing
  existing_mysql_host                = var.existing_mysql_host
  existing_mysql_port                = var.existing_mysql_port
  existing_mysql_database            = var.existing_mysql_database
  existing_mysql_username            = var.existing_mysql_username
  existing_mysql_password            = var.existing_mysql_password
}

# Keycloak Configuration
module "keycloak" {
  source                       = "./modules/keycloak-config"
  keycloak_url                 = var.keycloak_url
  keycloak_admin_client_id     = var.keycloak_admin_client_id
  keycloak_admin_client_secret = var.keycloak_admin_client_secret
  realm_name                   = var.realm_name
  netbird_domain               = var.netbird_domain
}

locals {
  # Combine all instances
  all_instances = concat(
    module.inventory_aws.instances,
    module.inventory_gcp.instances,
    module.inventory_azure.instances,
    module.inventory_manual.instances
  )

  # Filter by role
  management_nodes    = [for i in local.all_instances : i if i.role == "management"]
  relay_nodes         = [for i in local.all_instances : i if i.role == "relay"]
  reverse_proxy_nodes = [for i in local.all_instances : i if i.role == "reverse-proxy"]
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    netbird_domain         = var.netbird_domain
    netbird_version        = var.netbird_version
    
    # Database
    database_type          = module.database.database_type
    database_engine        = module.database.database_engine
    database_dsn           = module.database.database_dsn
    database_endpoint      = module.database.database_endpoint
    sqlite_database_path   = var.sqlite_database_path

    # Keycloak
    keycloak_url           = var.keycloak_url
    keycloak_realm         = module.keycloak.realm_name
    keycloak_client_id     = module.keycloak.client_id
    keycloak_client_secret = module.keycloak.client_secret
    keycloak_oidc_endpoint = module.keycloak.oidc_config_endpoint
    
    relay_auth_secret      = var.relay_auth_secret
    
    management_nodes       = local.management_nodes
    reverse_proxy_nodes    = local.reverse_proxy_nodes
    relay_nodes            = local.relay_nodes
  })
  filename = "${path.module}/../../configuration/inventory/terraform_inventory.yaml"
  file_permission = "0600"
}
