###############################################################################
# Terraform module to provision Keycloak realm, client, group hierarchy, and
# protocol mappers matching the Ansible deployment.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    keycloak = {
      source  = "MrPorter/keycloak"
      version = ">= 4.1.0"
    }
  }
}

provider "keycloak" {
  client_id     = var.keycloak_admin_client_id
  client_secret = var.keycloak_admin_client_secret
  username      = var.keycloak_admin_username
  password      = var.keycloak_admin_password
  url           = var.keycloak_base_url
  realm         = "master"
  tls_insecure  = var.keycloak_tls_insecure
}

resource "keycloak_realm" "netbird" {
  realm                      = var.keycloak_realm
  display_name               = var.keycloak_realm_display_name
  enabled                    = true
  registration_allowed       = false
  login_with_email_allowed   = true
  refresh_token_age          = 1800
  sso_session_idle_timeout   = 3600
  sso_session_max_lifespan   = 86400
  ssl_required               = "external"
}

resource "keycloak_openid_client" "netbird" {
  realm_id                 = keycloak_realm.netbird.id
  client_id                = var.keycloak_client_id
  name                     = "NetBird"
  description              = "NetBird OIDC Client"
  access_type              = "CONFIDENTIAL"
  standard_flow_enabled    = true
  direct_access_grants_enabled = false
  service_accounts_enabled = false
  root_url                 = var.keycloak_client_root_url
  base_url                 = var.keycloak_client_root_url
  admin_url                = var.keycloak_client_root_url
  valid_redirect_uris      = var.keycloak_client_redirect_uris
  web_origins              = [var.keycloak_client_root_url]
  secret                   = var.keycloak_client_secret
  full_scope_allowed       = false
  pkce_code_challenge_method = "S256"
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id            = keycloak_realm.netbird.id
  client_id           = keycloak_openid_client.netbird.id
  name                = "groups"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
  full_path           = false
}

data "keycloak_group" "existing" {
  for_each = { for grp in var.keycloak_groups : grp.name => grp if try(grp.id, null) != null }
  realm_id = keycloak_realm.netbird.id
  name     = each.key
}

resource "keycloak_group" "netbird_groups" {
  for_each = { for grp in var.keycloak_groups : grp.name => grp if try(grp.id, null) == null }

  realm_id    = keycloak_realm.netbird.id
  name        = each.value.name
  description = lookup(each.value, "description", "")
}