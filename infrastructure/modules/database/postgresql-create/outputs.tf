output "dsn" {
  description = "PostgreSQL Connection DSN"
  value = var.cloud_provider == "aws" ? (
    "host=${aws_db_instance.netbird[0].address} port=${aws_db_instance.netbird[0].port} dbname=${var.database_name} user=${var.username} password=${var.password} sslmode=require"
  ) : ""
  sensitive = true
}

output "endpoint" {
  description = "Database endpoint (hostname or IP)"
  value = var.cloud_provider == "aws" ? aws_db_instance.netbird[0].address : ""
}
