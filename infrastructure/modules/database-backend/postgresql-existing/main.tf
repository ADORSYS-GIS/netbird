variable "host" { type = string }
variable "port" { type = number }
variable "database" { type = string }
variable "username" { type = string }
variable "password" { type = string }
variable "sslmode" { type = string }

# Validate connection
resource "null_resource" "validate_connection" {
  triggers = {
    host = var.host
    port = var.port
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating PostgreSQL connection to ${var.host}:${var.port}..."
      # In real usage, ensure psql is installed or use a lightweight checker
      if command -v psql &> /dev/null; then
          PGPASSWORD='${var.password}' psql -h ${var.host} -p ${var.port} -U ${var.username} -d ${var.database} -c "SELECT version();"
      else
          echo "Warning: psql not found, skipping local validation check."
      fi
    EOT
  }
}

output "dsn" {
  value = "host=${var.host} port=${var.port} dbname=${var.database} user=${var.username} password=${var.password} sslmode=${var.sslmode}"
  sensitive = true
}

output "endpoint" {
    value = var.host
}
