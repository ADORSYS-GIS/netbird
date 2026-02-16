variable "host" { type = string }
variable "port" { type = number }
variable "database" { type = string }
variable "username" { type = string }
variable "password" { type = string }

resource "null_resource" "validate_connection" {
  triggers = {
    host = var.host
    port = var.port
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating MySQL connection..."
       if command -v mysql &> /dev/null; then
         mysql -h ${var.host} -P ${var.port} -u ${var.username} -p'${var.password}' -D ${var.database} -e "SELECT VERSION();"
       else
         echo "Warning: mysql client not found, skipping local validation check."
       fi
    EOT
  }
}

output "dsn" {
  value     = "${var.username}:${var.password}@tcp(${var.host}:${var.port})/${var.database}?charset=utf8mb4&parseTime=True&loc=Local"
  sensitive = true
}

output "endpoint" {
  value = var.host
}
