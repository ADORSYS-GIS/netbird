output "inventory_file" {
  description = "Path to the generated Ansible inventory file"
  value       = local.inventory_path
}

output "database_dsn" {
  description = "PostgreSQL Connection String"
  value       = module.database.database_dsn
  sensitive   = true
}

output "keycloak_client_id" {
  description = "NetBird OIDC Client ID"
  value       = module.keycloak.client_id
}

output "keycloak_backend_client_id" {
  description = "NetBird backend OIDC Client ID (for IDP management)"
  value       = module.keycloak.backend_client_id
}

output "keycloak_backend_client_secret" {
  description = "NetBird backend OIDC Client Secret (for IDP management)"
  value       = module.keycloak.backend_client_secret
  sensitive   = true
}

output "keycloak_issuer_url" {
  description = "OIDC Issuer URL"
  value       = module.keycloak.issuer_url
}
