output "realm_name" {
  value = local.realm_name
}

# Frontend client (used by dashboard + CLI)
output "client_id" {
  description = "The public netbird-client ID (used in management.json HttpConfig.AuthAudience)"
  value       = keycloak_openid_client.netbird_client.client_id
}

# Backend client (used by management service for IDP user sync)
output "backend_client_id" {
  description = "The confidential netbird-backend client ID (used in management.json IdpManagerConfig)"
  value       = keycloak_openid_client.netbird_backend.client_id
}

output "backend_client_secret" {
  description = "The netbird-backend client secret (used in management.json IdpManagerConfig)"
  value       = keycloak_openid_client.netbird_backend.client_secret
  sensitive   = true
}

output "oidc_config_endpoint" {
  value = "${var.keycloak_url}/realms/${local.realm_name}/.well-known/openid-configuration"
}

output "issuer_url" {
  value = "${var.keycloak_url}/realms/${local.realm_name}"
}
