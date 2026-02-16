output "inventory_file" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "database_dsn" {
  description = "PostgreSQL Connection String"
  value       = module.database.dsn
  sensitive   = true
}

output "keycloak_client_id" {
  description = "NetBird OIDC Client ID"
  value       = module.keycloak.client_id
}

output "keycloak_client_secret" {
  description = "NetBird OIDC Client Secret"
  value       = module.keycloak.client_secret
  sensitive   = true
}

output "keycloak_issuer_url" {
  description = "OIDC Issuer URL"
  value       = module.keycloak.issuer_url
}
