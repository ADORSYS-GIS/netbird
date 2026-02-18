variable "keycloak_url" { type = string }
variable "keycloak_admin_username" { type = string }
variable "keycloak_admin_password" { type = string }
variable "realm_name" { type = string }
variable "use_existing_realm" {
  type    = bool
  default = false
}
variable "netbird_domain" { type = string }
variable "netbird_admin_email" { type = string }
variable "netbird_admin_password" { type = string }
