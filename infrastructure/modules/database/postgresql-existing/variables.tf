variable "host" { type = string }
variable "port" { type = number }
variable "database" { type = string }
variable "username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}
variable "sslmode" { type = string }
