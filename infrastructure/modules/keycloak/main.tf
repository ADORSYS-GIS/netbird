terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Realm
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Client Scope: "api"
# Adds an audience claim for netbird-client so management can validate tokens.
# Ref: https://docs.netbird.io/selfhosted/identity-providers/advanced/keycloak#step-6-create-client-scope
# ---------------------------------------------------------------------------

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

  included_client_audience = "netbird-client"
  add_to_access_token      = true
  add_to_id_token          = false
}

# ---------------------------------------------------------------------------
# Client Scope: "groups"
# Adds group membership claim to tokens.
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Client 1: netbird-client (PUBLIC — used by dashboard + CLI)
# Ref: https://docs.netbird.io/selfhosted/identity-providers/advanced/keycloak#step-4-create-net-bird-client
# ---------------------------------------------------------------------------

resource "keycloak_openid_client" "netbird_client" {
  realm_id  = local.realm_id
  client_id = "netbird-client"
  name      = "NetBird Client"
  enabled   = true

  # PUBLIC: no client secret, uses PKCE for security
  access_type = "PUBLIC"

  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false

  # Ref: Step 5 — Access Settings
  root_url = "https://${var.netbird_domain}"

  valid_redirect_uris = [
    "https://${var.netbird_domain}/*",
    "https://${var.netbird_domain}/nb-auth",
    "https://${var.netbird_domain}/nb-silent-auth",
    "http://localhost:53000/", # CLI device auth flow
    "http://localhost:54000/", # CLI PKCE flow
  ]

  valid_post_logout_redirect_uris = [
    "https://${var.netbird_domain}/*",
  ]

  web_origins = ["+"] # Allows all valid redirect URI origins
}

# Attach "api" and "groups" scopes as defaults to netbird-client
# Ref: Step 7 — Add Client Scope to NetBird Client
resource "keycloak_openid_client_default_scopes" "netbird_client_scopes" {
  realm_id  = local.realm_id
  client_id = keycloak_openid_client.netbird_client.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "offline_access",
    keycloak_openid_client_scope.api.name,
    keycloak_openid_client_scope.groups.name,
  ]
}

# ---------------------------------------------------------------------------
# Client 2: netbird-backend (CONFIDENTIAL — used by management service IDP API)
# Ref: https://docs.netbird.io/selfhosted/identity-providers/advanced/keycloak#step-8-create-net-bird-backend-client
# ---------------------------------------------------------------------------

resource "keycloak_openid_client" "netbird_backend" {
  realm_id  = local.realm_id
  client_id = "netbird-backend"
  name      = "NetBird Backend"
  enabled   = true

  # CONFIDENTIAL: has a client secret, used server-to-server only
  access_type = "CONFIDENTIAL"

  standard_flow_enabled        = false
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = true # Enables client_credentials grant
}

# Assign view-users role to netbird-backend service account
# Ref: Step 9 — Add View-Users Role
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

# ---------------------------------------------------------------------------
# Default Admin User
# ---------------------------------------------------------------------------

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
