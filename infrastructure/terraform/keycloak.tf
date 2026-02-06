# NetBird Realm
resource "keycloak_realm" "netbird" {
  realm   = var.keycloak_realm
  enabled = true
}

# NetBird API Scope
resource "keycloak_openid_client_scope" "netbird_api" {
  realm_id = keycloak_realm.netbird.id
  name     = "api"
}

# Management Client (Confidential)
resource "keycloak_openid_client" "netbird_management" {
  realm_id              = keycloak_realm.netbird.id
  client_id             = var.keycloak_mgmt_client_id
  name                  = "NetBird Management"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  service_accounts_enabled = true

  valid_redirect_uris = [
    "https://netbird.${var.netbird_domain}/*"
  ]

  web_origins = [
    "+"
  ]

  # Enable Device Flow for CLI login
  extra_config = {
    "oauth2.device.authorization.grant.enabled" = "true"
  }
}

# Dashboard Client (Public)
resource "keycloak_openid_client" "netbird_dashboard" {
  realm_id              = keycloak_realm.netbird.id
  client_id             = var.keycloak_client_id
  name                  = "NetBird Dashboard"
  enabled               = true
  access_type           = "PUBLIC"
  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://netbird.${var.netbird_domain}/*"
  ]

  web_origins = [
    "+"
  ]
}

# Add 'api' scope to both clients
resource "keycloak_openid_client_default_scopes" "mgmt_scopes" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_management.id
  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.netbird_api.name
  ]
}

resource "keycloak_openid_client_default_scopes" "dashboard_scopes" {
  realm_id  = keycloak_realm.netbird.id
  client_id = keycloak_openid_client.netbird_dashboard.id
  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.netbird_api.name
  ]
}

# Assign 'view-users' role to Management Service Account
data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.netbird.id
  client_id = "realm-management"
}

data "keycloak_role" "view_users" {
  realm_id  = keycloak_realm.netbird.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "view-users"
}

resource "keycloak_openid_client_service_account_role" "mgmt_service_account_view_users" {
  realm_id                = keycloak_realm.netbird.id
  service_account_user_id = keycloak_openid_client.netbird_management.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = data.keycloak_role.view_users.name
}

# Outputs for Helm
output "keycloak_mgmt_client_secret" {
  value     = keycloak_openid_client.netbird_management.client_secret
  sensitive = true
}
