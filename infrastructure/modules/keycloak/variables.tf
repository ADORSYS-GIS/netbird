variable "keycloak_url" {
  description = "Keycloak server URL"
  type        = string
}

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "realm_name" {
  description = "Keycloak realm name for NetBird"
  type        = string
}

variable "use_existing_realm" {
  description = "Use existing realm instead of creating new one"
  type        = bool
  default     = false
}

variable "netbird_domain" {
  description = "NetBird domain for OIDC redirect URIs"
  type        = string
}

variable "netbird_admin_email" {
  description = "Default NetBird admin user email"
  type        = string
}

variable "netbird_admin_password" {
  description = "Default NetBird admin user password"
  type        = string
  sensitive   = true
}
