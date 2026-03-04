output "database_type" {
  value = var.database_type
}

output "database_engine" {
  value = local.use_sqlite ? "sqlite" : "postgres"
}

output "database_dsn" {
  value     = local.use_sqlite ? local.sqlite_dsn : local.postgres_dsn
  sensitive = true
}

output "database_endpoint" {
  value = local.use_sqlite ? "local" : var.existing_postgresql_host
}

output "database_port" {
  value = local.use_sqlite ? 0 : var.existing_postgresql_port
}

output "database_name" {
  value = local.use_sqlite ? "" : var.existing_postgresql_database
}

output "database_username" {
  value = local.use_sqlite ? "" : var.existing_postgresql_username
}

output "database_password" {
  value     = local.use_sqlite ? "" : var.existing_postgresql_password
  sensitive = true
}

output "database_sslmode" {
  value = local.use_postgresql && local.use_existing ? var.existing_postgresql_sslmode : "require"
}

output "database_channel_binding" {
  value = local.use_postgresql && local.use_existing ? var.existing_postgresql_channel_binding : "prefer"
}
