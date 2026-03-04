output "inventory_file" {
  description = "Path to generated Ansible inventory"
  value       = local.inventory_path
}

output "database_dsn" {
  description = "Database connection string"
  value       = module.database.database_dsn
  sensitive   = true
}

output "keycloak_client_id" {
  description = "NetBird OIDC client ID"
  value       = module.keycloak.client_id
}

output "keycloak_backend_client_id" {
  description = "NetBird backend client ID"
  value       = module.keycloak.backend_client_id
}

output "keycloak_backend_client_secret" {
  description = "NetBird backend client secret"
  value       = module.keycloak.backend_client_secret
  sensitive   = true
}

output "keycloak_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.keycloak.issuer_url
}

output "management_nodes" {
  description = "Management server nodes"
  value       = module.inventory.management_nodes
}

output "reverse_proxy_nodes" {
  description = "Reverse proxy nodes"
  value       = module.inventory.reverse_proxy_nodes
}

output "relay_nodes" {
  description = "Relay server nodes"
  value       = module.inventory.relay_nodes
}

output "haproxy_stats_password" {
  description = "HAProxy stats UI password"
  value       = var.haproxy_stats_password != "" ? var.haproxy_stats_password : random_password.haproxy_stats_password.result
  sensitive   = true
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    domain            = var.netbird_domain
    dashboard_url     = "https://${var.netbird_domain}"
    haproxy_stats_url = "http://${var.netbird_domain}:8404/stats"
    proxy_type        = var.proxy_type
    database_type     = var.database_type
    pgbouncer_enabled = var.enable_pgbouncer
    management_count  = length(module.inventory.management_nodes)
    proxy_count       = length(module.inventory.reverse_proxy_nodes)
    relay_count       = length(module.inventory.relay_nodes)
  }
}

output "next_steps" {
  description = "Commands to run after Terraform apply"
  value       = var.auto_deploy ? "Deployment complete. Access dashboard at https://${var.netbird_domain}" : <<-EOT
    Run Ansible deployment:
      cd ../../configuration/ansible
      ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
    
    Or enable auto_deploy in terraform.tfvars:
      auto_deploy = true
  EOT
}
