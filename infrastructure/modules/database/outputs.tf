output "database_type" {
  value = var.database_type
}

output "database_engine" {
  value = local.use_sqlite ? "sqlite" : "postgres"
}

output "database_dsn" {
  value = local.use_sqlite ? module.sqlite[0].dsn : (
    local.create_database ? module.postgresql_create[0].dsn : module.postgresql_existing[0].dsn
  )
  sensitive = true
}

output "database_endpoint" {
  value = local.use_sqlite ? "local" : (
    local.create_database ? module.postgresql_create[0].endpoint : var.existing_postgresql_host
  )
}

output "database_port" {
  value = local.use_sqlite ? 0 : (
    local.create_database ? 5432 : var.existing_postgresql_port
  )
}

output "database_name" {
  value = local.use_sqlite ? "" : (
    local.create_database ? var.postgresql_database_name : var.existing_postgresql_database
  )
}

output "database_username" {
  value = local.use_sqlite ? "" : (
    local.create_database ? var.postgresql_username : var.existing_postgresql_username
  )
}

output "database_password" {
  value = local.use_sqlite ? "" : (
    local.create_database ? var.postgresql_password : var.existing_postgresql_password
  )
  sensitive = true
}

output "database_sslmode" {
  value = local.use_postgresql && local.use_existing ? var.existing_postgresql_sslmode : "require"
}
