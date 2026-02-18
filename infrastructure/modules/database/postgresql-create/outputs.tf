output "dsn" {
  description = "PostgreSQL Connection DSN"
  value = var.cloud_provider == "aws" ? (
    "host=${aws_db_instance.netbird[0].address} port=${aws_db_instance.netbird[0].port} dbname=${var.database_name} user=${var.username} password=${var.password} sslmode=require"
  ) : var.cloud_provider == "gcp" ? (
    "host=${google_sql_database_instance.netbird[0].public_ip_address} port=5432 dbname=${var.database_name} user=${var.username} password=${var.password} sslmode=require"
  ) : var.cloud_provider == "azure" ? (
    "host=${azurerm_postgresql_flexible_server.netbird[0].fqdn} port=5432 dbname=${var.database_name} user=${var.username} password=${var.password} sslmode=require"
  ) : ""
  sensitive = true
}

output "endpoint" {
  description = "Database endpoint (hostname or IP)"
  value = var.cloud_provider == "aws" ? aws_db_instance.netbird[0].address : (
    var.cloud_provider == "gcp" ? google_sql_database_instance.netbird[0].public_ip_address : (
      var.cloud_provider == "azure" ? azurerm_postgresql_flexible_server.netbird[0].fqdn : ""
    )
  )
}
