output "database_type" {
  value       = var.database_type
}

output "database_engine" {
  value = local.use_sqlite ? "sqlite" : (
    local.use_postgresql ? "postgres" : "mysql"
  )
}

output "database_dsn" {
  value = local.use_sqlite ? module.sqlite[0].dsn : (
    local.use_postgresql && local.create_database ? module.postgresql_create[0].dsn : (
      local.use_postgresql && local.use_existing ? module.postgresql_existing[0].dsn : (
        local.use_mysql ? module.mysql_existing[0].dsn : ""
      )
    )
  )
  sensitive   = true
}

output "database_endpoint" {
  value = local.use_sqlite ? "local" : (
    local.use_postgresql && local.create_database ? module.postgresql_create[0].endpoint : (
      local.use_postgresql && local.use_existing ? var.existing_postgresql_host : (
        local.use_mysql ? var.existing_mysql_host : ""
      )
    )
  )
}
