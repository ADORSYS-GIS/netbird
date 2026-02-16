variable "database_path" { type = string }

output "dsn" {
  value = var.database_path
}
