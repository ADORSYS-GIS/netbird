terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.0.0"
    }
  }
}

# Realm configuration
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

# Client scope: api
# Adds audience claim for netbird-client so management can validate tokens
resource "keycloak_openid_client_scope" "api" {
  realm_id               = local.realm_id
  name                   = "api"
  include_in_token_scope = true
  gui_order              = 1
}

resource "keycloak_openid_audience_protocol_mapper" "api_audience" {
  realm_id        = local.realm_id
  client_scope_id = keycloak_openid_client_scope.api.id
  name            = "Audience for NetBird Management API"

  included_client_audience = keycloak_openid_client.netbird_client.client_id
  add_to_access_token      = true
  add_to_id_token          = false
}

# Client scope: groups
# Adds group membership claim to tokens
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = local.realm_id
  name                   = "groups"
  include_in_token_scope = true
  gui_order              = 2
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_mapper" {
  realm_id        = local.realm_id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false

  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Public client for dashboard and CLI
resource "keycloak_openid_client" "netbird_client" {
  realm_id  = local.realm_id
  client_id = "netbird-client"
  name      = "NetBird Client"
  enabled   = true

  access_type = "PUBLIC"

  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = false

  root_url = "https://${var.netbird_domain}"

  valid_redirect_uris = [
    "https://${var.netbird_domain}/*",
    "https://${var.netbird_domain}/nb-auth",
    "https://${var.netbird_domain}/nb-silent-auth",
    "http://localhost:53000/*",
    "http://localhost:54000/*",
  ]

  valid_post_logout_redirect_uris = [
    "+",
    "https://${var.netbird_domain}/*",
  ]

  web_origins = ["+"]
}

# Attach api and groups scopes to netbird-client
resource "keycloak_openid_client_default_scopes" "netbird_client_scopes" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.netbird_client.id
  default_scopes = [
    "openid",
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.api.name,
    keycloak_openid_client_scope.groups.name,
  ]
}

# Confidential client for management service IDP API
resource "keycloak_openid_client" "netbird_backend" {
  realm_id  = local.realm_id
  client_id = "netbird-backend"
  name      = "NetBird Backend"
  enabled   = true

  access_type = "CONFIDENTIAL"

  standard_flow_enabled        = false
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = true
}

# Assign view-users role to netbird-backend service account
data "keycloak_openid_client" "realm_management" {
  realm_id  = local.realm_id
  client_id = "realm-management"
}

resource "keycloak_openid_client_service_account_role" "netbird_backend_view_users" {
  realm_id                = local.realm_id
  service_account_user_id = keycloak_openid_client.netbird_backend.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = "view-users"
}

# Default admin user
resource "keycloak_user" "netbird_admin" {
  realm_id = local.realm_id
  username = "netbird-admin"
  enabled  = true

  email      = var.netbird_admin_email
  first_name = "NetBird"
  last_name  = "Admin"

  initial_password {
    value     = var.netbird_admin_password
    temporary = false
  }
}
