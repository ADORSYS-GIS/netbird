terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.0.0"
    }
  }
}

variable "keycloak_url" { type = string }
variable "keycloak_admin_client_id" { type = string }
variable "keycloak_admin_client_secret" { type = string }
variable "realm_name" { type = string }
variable "netbird_domain" { type = string }

provider "keycloak" {
  client_id     = var.keycloak_admin_client_id
  client_secret = var.keycloak_admin_client_secret
  url           = var.keycloak_url
  realm         = "master"
}

# Create NetBird Realm
resource "keycloak_realm" "netbird" {
  realm        = var.realm_name
  enabled      = true
  display_name = "NetBird Network"

  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "10h"

  login_with_email_allowed = true
  duplicate_emails_allowed = false
}

# Create OIDC Client
resource "keycloak_openid_client" "netbird_client" {
  realm_id  = keycloak_realm.netbird.id
  client_id = "netbird-client"
  name      = "NetBird Management"
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = true

  valid_redirect_uris = [
    "https://${var.netbird_domain}/*",
    "https://${var.netbird_domain}/nb-auth",
    "https://${var.netbird_domain}/nb-silent-auth",
  ]

  web_origins = ["https://${var.netbird_domain}"]
}

# Service account roles
resource "keycloak_openid_client_service_account_role" "netbird_realm_management" {
  realm_id                = keycloak_realm.netbird.id
  service_account_user_id = keycloak_openid_client.netbird_client.service_account_user_id
  client_id               = "realm-management"
  role                    = "view-users"
}

# Outputs
output "realm_name" {
  value = keycloak_realm.netbird.realm
}

output "client_id" {
  value = keycloak_openid_client.netbird_client.client_id
}

output "client_secret" {
  value     = keycloak_openid_client.netbird_client.client_secret
  sensitive = true
}

output "oidc_config_endpoint" {
  value = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}/.well-known/openid-configuration"
}

output "issuer_url" {
  value = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}"
}
