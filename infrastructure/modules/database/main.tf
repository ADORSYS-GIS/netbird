# Unified database backend module
# Supports: SQLite, PostgreSQL (create/existing)

locals {
  # Determine which backend to use
  use_sqlite     = var.database_type == "sqlite"
  use_postgresql = var.database_type == "postgresql"

  # Determine if we connect to existing
  use_existing = var.database_mode == "existing"
}

# Inclusion logic
module "sqlite" {
  source = "./sqlite"
  count  = local.use_sqlite ? 1 : 0

  database_path = var.sqlite_database_path
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
