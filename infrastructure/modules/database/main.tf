locals {
  use_sqlite     = var.database_type == "sqlite"
  use_postgresql = var.database_type == "postgresql"
  use_existing   = var.database_mode == "existing"
}

# SQLite DSN - just the file path
locals {
  sqlite_dsn = var.sqlite_database_path
}

# PostgreSQL DSN - standard URI format with URL-encoded password
locals {
  postgres_dsn = "postgresql://${var.existing_postgresql_username}:${urlencode(var.existing_postgresql_password)}@${var.existing_postgresql_host}:${var.existing_postgresql_port}/${var.existing_postgresql_database}?sslmode=${var.existing_postgresql_sslmode}&channel_binding=${var.existing_postgresql_channel_binding}"
}

# Validation: Ensure PostgreSQL variables are set when using PostgreSQL
resource "null_resource" "validate_postgres_config" {
  count = local.use_postgresql ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.existing_postgresql_host != ""
      error_message = "existing_postgresql_host must be set when database_type is 'postgresql'"
    }
    precondition {
      condition     = var.existing_postgresql_database != ""
      error_message = "existing_postgresql_database must be set when database_type is 'postgresql'"
    }
    precondition {
      condition     = var.existing_postgresql_username != ""
      error_message = "existing_postgresql_username must be set when database_type is 'postgresql'"
    }
    precondition {
      condition     = var.existing_postgresql_password != ""
      error_message = "existing_postgresql_password must be set when database_type is 'postgresql'"
    }
  }
}
