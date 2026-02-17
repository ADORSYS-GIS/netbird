terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.0.0"
    }
  }
}

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



# Create or Fetch NetBird Realm
data "keycloak_realm" "existing" {
  count = var.use_existing_realm ? 1 : 0
  realm = var.realm_name
}

resource "keycloak_realm" "netbird" {
  count        = var.use_existing_realm ? 0 : 1
  realm        = var.realm_name
  enabled      = true
  display_name = "NetBird Network"

  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "10h"

  login_with_email_allowed = true
  duplicate_emails_allowed = false
}

locals {
  realm_id   = var.use_existing_realm ? data.keycloak_realm.existing[0].id : keycloak_realm.netbird[0].id
  realm_name = var.use_existing_realm ? data.keycloak_realm.existing[0].realm : keycloak_realm.netbird[0].realm
}

# Create OIDC Client
resource "keycloak_openid_client" "netbird_client" {
  realm_id  = local.realm_id
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

# Create Groups Client Scope
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = local.realm_id
  name                   = "groups"
  include_in_token_scope = true
  gui_order              = 1
}

# Add Group Membership Mapper
resource "keycloak_openid_group_membership_protocol_mapper" "group_mapper" {
  realm_id            = local.realm_id
  client_scope_id     = keycloak_openid_client_scope.groups.id
  name                = "groups"
  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Attach scope to client
resource "keycloak_openid_client_default_scopes" "client_default_scopes" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.netbird_client.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name,
  ]
}

# Service account roles
data "keycloak_openid_client" "realm_management" {
  realm_id  = local.realm_id
  client_id = "realm-management"
}

resource "keycloak_openid_client_service_account_role" "netbird_realm_management" {
  realm_id                = local.realm_id
  service_account_user_id = keycloak_openid_client.netbird_client.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = "view-users"
}

# Create Default NetBird User
resource "keycloak_user" "netbird_admin" {
  realm_id = local.realm_id
  username = "netbird"
  enabled  = true

  email      = var.netbird_admin_email
  first_name = "NetBird"
  last_name  = "Admin"

  initial_password {
    value     = var.netbird_admin_password
    temporary = false
  }
}

# Outputs
output "realm_name" {
  value = local.realm_name
}

output "client_id" {
  value = keycloak_openid_client.netbird_client.client_id
}

output "client_secret" {
  value     = keycloak_openid_client.netbird_client.client_secret
  sensitive = true
}

output "oidc_config_endpoint" {
  value = "${var.keycloak_url}/realms/${local.realm_name}/.well-known/openid-configuration"
}

output "issuer_url" {
  value = "${var.keycloak_url}/realms/${local.realm_name}"
}
