output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "netbird_url" {
  description = "NetBird URL"
  value       = "https://${var.netbird_domain}"
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.database.database_endpoint
}
