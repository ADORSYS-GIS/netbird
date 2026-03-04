# =============================================================================
# NetBird Keycloak Configuration
# Based on: https://docs.netbird.io/selfhosted/identity-providers/keycloak
# =============================================================================

# NetBird Realm
resource "keycloak_realm" "netbird" {
  realm                    = var.keycloak_realm
  enabled                  = true
  display_name             = "NetBird"
  display_name_html        = "<b>NetBird</b>"
  login_with_email_allowed = true
  duplicate_emails_allowed = false
  reset_password_allowed   = true
  remember_me              = true
  verify_email             = false

  # Security settings
  password_policy = "upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and length(12) and forceExpiredPasswordChange(365) and notUsername"

  # Brute-force protection
  security_defenses {
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }

  # Token settings
  access_token_lifespan                   = "5m"
  access_token_lifespan_for_implicit_flow = "5m"
  sso_session_idle_timeout                = "30m"
  sso_session_max_lifespan                = "10h"
  offline_session_idle_timeout            = "720h"
  offline_session_max_lifespan_enabled    = true
  offline_session_max_lifespan            = "1440h"
}

# =============================================================================
# Client Scopes
# =============================================================================

# NetBird API Scope - Required for API access
resource "keycloak_openid_client_scope" "netbird_api" {
  realm_id               = keycloak_realm.netbird.id
  name                   = "api"
  description            = "NetBird API access scope"
  include_in_token_scope = true
}

# Groups Client Scope - Required for group sync
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.netbird.id
  name                   = "groups"
  description            = "User group membership"
  include_in_token_scope = true
}

# Groups Protocol Mapper - Adds group membership to tokens
resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id        = keycloak_realm.netbird.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"

  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# =============================================================================
# Backend Client (Confidential) - For Management API
# =============================================================================

resource "keycloak_openid_client" "netbird_backend" {
  realm_id                     = keycloak_realm.netbird.id
  client_id                    = var.keycloak_mgmt_client_id
  name                         = "NetBird Backend"
  description                  = "NetBird Management Backend Client"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = true

  # Device Authorization Grant for CLI login
  oauth2_device_authorization_grant_enabled = true

  valid_redirect_uris = [
    "https://${var.netbird_domain}",
    "https://${var.netbird_domain}/*",
    "https://${var.netbird_domain}/silent-auth",
    "https://${var.netbird_domain}/auth",
    "http://localhost:53000/*"
  ]

  valid_post_logout_redirect_uris = [
    "https://${var.netbird_domain}/*",
    "+"
  ]

  web_origins = [
    "https://${var.netbird_domain}",
    "+"
  ]

  # PKCE settings
  pkce_code_challenge_method = "S256"
}

# Explicitly add sub mapper to Access Token for Backend
resource "keycloak_openid_user_property_protocol_mapper" "backend_sub" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_backend.id
  name      = "sub"

  user_property       = "id"
  claim_name          = "sub"
  add_to_id_token     = true
  add_to_access_token = true
}

# =============================================================================
# Dashboard/CLI Client (Public) - For Frontend and CLI
# =============================================================================

resource "keycloak_openid_client" "netbird_dashboard" {
  realm_id                     = keycloak_realm.netbird.id
  client_id                    = var.keycloak_client_id
  name                         = "NetBird Dashboard"
  description                  = "NetBird Dashboard and CLI Client"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true

  # Device Authorization Grant for CLI login
  oauth2_device_authorization_grant_enabled = true

  valid_redirect_uris = [
    "https://${var.netbird_domain}",
    "https://${var.netbird_domain}/*",
    "https://${var.netbird_domain}/silent-auth",
    "https://${var.netbird_domain}/auth",
    "http://localhost:53000/*"
  ]

  valid_post_logout_redirect_uris = [
    "https://${var.netbird_domain}/*",
    "+"
  ]

  web_origins = [
    "https://${var.netbird_domain}",
    "+"
  ]

  # PKCE settings - Required for public clients
  pkce_code_challenge_method = "S256"
}

# Explicitly add sub mapper to Access Token for Dashboard
resource "keycloak_openid_user_property_protocol_mapper" "dashboard_sub" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_dashboard.id
  name      = "sub"

  user_property       = "id"
  claim_name          = "sub"
  add_to_id_token     = true
  add_to_access_token = true
}

# =============================================================================
# Audience Mapper - Critical for token validation
# =============================================================================

# Dashboard needs to include backend client_id in audience
resource "keycloak_openid_audience_protocol_mapper" "dashboard_audience" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_dashboard.id
  name      = "netbird-backend-audience"

  included_client_audience = keycloak_openid_client.netbird_backend.client_id
  add_to_id_token          = true
  add_to_access_token      = true
}

# =============================================================================
# Client Scopes Assignment
# =============================================================================

# Backend client scopes
resource "keycloak_openid_client_default_scopes" "backend_scopes" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_backend.id
  default_scopes = [
    "profile",
    "email",
    "openid",
    keycloak_openid_client_scope.netbird_api.name,
    keycloak_openid_client_scope.groups.name
  ]
}

# Dashboard client scopes
resource "keycloak_openid_client_default_scopes" "dashboard_scopes" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_dashboard.id
  default_scopes = [
    "profile",
    "email",
    "openid",
    keycloak_openid_client_scope.netbird_api.name,
    keycloak_openid_client_scope.groups.name
  ]
}

# =============================================================================
# Service Account Roles - Required for user management
# =============================================================================

data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.netbird.id
  client_id = "realm-management"
}

data "keycloak_role" "view_users" {
  realm_id  = keycloak_realm.netbird.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "view-users"
}

data "keycloak_role" "query_users" {
  realm_id  = keycloak_realm.netbird.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "query-users"
}

data "keycloak_role" "query_groups" {
  realm_id  = keycloak_realm.netbird.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "query-groups"
}

data "keycloak_role" "view_realm" {
  realm_id  = keycloak_realm.netbird.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "view-realm"
}

# Assign roles to backend service account
resource "keycloak_openid_client_service_account_role" "backend_service_account_roles" {
  for_each = toset([
    data.keycloak_role.view_users.name,
    data.keycloak_role.query_users.name,
    data.keycloak_role.query_groups.name,
    data.keycloak_role.view_realm.name
  ])

  realm_id                = keycloak_realm.netbird.id
  service_account_user_id = keycloak_openid_client.netbird_backend.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = each.value
}

# =============================================================================
# Initial Admin User (Optional)
# =============================================================================

resource "keycloak_user" "netbird_admin" {
  realm_id = keycloak_realm.netbird.id
  username = "netbird-admin"
  enabled  = true

  email          = var.netbird_admin_email
  email_verified = true
  first_name     = "NetBird"
  last_name      = "Admin"

  initial_password {
    value     = var.netbird_admin_password
    temporary = true
  }
}

# =============================================================================
# NetBird Admin Group
# =============================================================================

resource "keycloak_group" "netbird_admins" {
  realm_id = keycloak_realm.netbird.id
  name     = "netbird-admins"
}

# Add admin user to admin group
resource "keycloak_group_memberships" "netbird_admin_membership" {
  realm_id = keycloak_realm.netbird.id
  group_id = keycloak_group.netbird_admins.id

  members = [
    keycloak_user.netbird_admin.username
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "keycloak_backend_client_secret" {
  description = "Client secret for NetBird backend"
  value       = keycloak_openid_client.netbird_backend.client_secret
  sensitive   = true
}

output "keycloak_realm_name" {
  description = "Keycloak realm name"
  value       = keycloak_realm.netbird.realm
}

output "keycloak_issuer_url" {
  description = "Keycloak OIDC issuer URL"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}"
}

output "keycloak_token_endpoint" {
  description = "Keycloak token endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}/protocol/openid-connect/token"
}

output "keycloak_device_auth_endpoint" {
  description = "Keycloak device authorization endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}/protocol/openid-connect/auth/device"
}

output "keycloak_jwks_uri" {
  description = "Keycloak JWKS URI"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}/protocol/openid-connect/certs"
}
