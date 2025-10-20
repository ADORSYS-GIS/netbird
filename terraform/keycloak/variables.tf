variable "keycloak_base_url" {
  description = "Base URL of Keycloak (e.g., https://keycloak.localhost)"
  type        = string
}

variable "keycloak_tls_insecure" {
  description = "Whether to skip TLS verification"
  type        = bool
  default     = true
}

variable "keycloak_admin_client_id" {
  description = "Keycloak admin client ID"
  type        = string
  default     = "admin-cli"
}

variable "keycloak_admin_client_secret" {
  description = "Keycloak admin client secret, if required"
  type        = string
  default     = ""
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

variable "keycloak_realm" {
  description = "Realm name for NetBird"
  type        = string
}

variable "keycloak_realm_display_name" {
  description = "Realm display name"
  type        = string
  default     = "NetBird Realm"
}

variable "keycloak_client_id" {
  description = "OIDC client ID for NetBird"
  type        = string
}

variable "keycloak_client_secret" {
  description = "OIDC client secret (NetBird)"
  type        = string
  sensitive   = true
}

variable "keycloak_client_root_url" {
  description = "Root URL for NetBird dashboard"
  type        = string
}

variable "keycloak_client_redirect_uris" {
  description = "Allowed redirect URIs"
  type        = list(string)
}

variable "keycloak_groups" {
  description = "List of groups to ensure exist"
  type = list(object({
    name        = string
    description = optional(string)
    id          = optional(string)
  }))
  default = []
}