# Unified database backend module
# Supports: SQLite, PostgreSQL (create/existing), MySQL (existing)

locals {
  # Determine which backend to use
  use_sqlite     = var.database_type == "sqlite"
  use_postgresql = var.database_type == "postgresql"
  use_mysql      = var.database_type == "mysql"
  
  # Determine if we create or connect to existing
  create_database = var.database_mode == "create"
  use_existing    = var.database_mode == "existing"
  
  # Validation
  valid_type = contains(["sqlite", "postgresql", "mysql"], var.database_type)
  valid_mode = contains(["create", "existing"], var.database_mode)
}

# Validation checks
resource "null_resource" "validate_config" {
  lifecycle {
    precondition {
      condition     = local.valid_type
      error_message = "database_type must be one of: sqlite, postgresql, mysql"
    }
    
    precondition {
      condition     = local.valid_mode
      error_message = "database_mode must be one of: create, existing"
    }
    
    precondition {
      condition     = !(local.use_sqlite && var.database_mode == "create")
      error_message = "SQLite does not support 'create' mode. Use 'existing' mode (local file path)."
    }
    
    precondition {
      condition     = !(local.use_sqlite && var.enable_ha)
      error_message = "SQLite is NOT supported for multi-node HA deployments!"
    }
  }
}

# Include appropriate sub-module based on selection
module "sqlite" {
  source = "./sqlite"
  count  = local.use_sqlite ? 1 : 0
  
  database_path = var.sqlite_database_path
}

module "postgresql_create" {
  source = "./postgresql-create"
  count  = local.use_postgresql && local.create_database ? 1 : 0
  
  cloud_provider        = var.cloud_provider
  instance_class        = var.postgresql_instance_class
  storage_gb            = var.postgresql_storage_gb
  database_name         = var.postgresql_database_name
  username              = var.postgresql_username
  password              = var.postgresql_password
  multi_az              = var.postgresql_multi_az
  backup_retention_days = var.postgresql_backup_retention_days
  vpc_id                = var.vpc_id
  subnet_ids            = var.database_subnet_ids
  security_group_ids    = var.database_security_group_ids
  
  tags = var.tags
}

module "postgresql_existing" {
  source = "./postgresql-existing"
  count  = local.use_postgresql && local.use_existing ? 1 : 0
  
  host     = var.existing_postgresql_host
  port     = var.existing_postgresql_port
  database = var.existing_postgresql_database
  username = var.existing_postgresql_username
  password = var.existing_postgresql_password
  sslmode  = var.existing_postgresql_sslmode
}

module "mysql_existing" {
  source = "./mysql-existing"
  count  = local.use_mysql && local.use_existing ? 1 : 0
  
  host     = var.existing_mysql_host
  port     = var.existing_mysql_port
  database = var.existing_mysql_database
  username = var.existing_mysql_username
  password = var.existing_mysql_password
}
