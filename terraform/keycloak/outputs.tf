output "realm_id" {
  description = "Keycloak realm UUID"
  value       = keycloak_realm.netbird.id
}

output "client_id" {
  description = "Keycloak client UUID"
  value       = keycloak_openid_client.netbird.id
}