output "dsn" {
  value     = "host=${var.host} port=${var.port} dbname=${var.database} user=${var.username} password=${var.password} sslmode=${var.sslmode}"
  sensitive = true
}

output "endpoint" {
  value = var.host
}
