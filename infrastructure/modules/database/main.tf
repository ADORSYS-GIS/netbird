# Unified database backend module
# Supports: SQLite, PostgreSQL (create/existing)

locals {
  # Determine which backend to use
  use_sqlite     = var.database_type == "sqlite"
  use_postgresql = var.database_type == "postgresql"

  # Determine if we create or connect to existing
  create_database = var.database_mode == "create"
  use_existing    = var.database_mode == "existing"
}

# Inclusion logic
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
