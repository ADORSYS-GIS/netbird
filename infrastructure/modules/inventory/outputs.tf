output "all_instances" {
  description = "All discovered instances"
  value       = local.all_instances
}

output "management_nodes" {
  description = "Management server instances"
  value       = local.management_nodes
}

output "relay_nodes" {
  description = "Relay server instances"
  value       = local.relay_nodes
}

output "reverse_proxy_nodes" {
  description = "Reverse proxy instances"
  value       = local.reverse_proxy_nodes
}

output "vpc_id" {
  description = "AWS VPC ID (if using AWS)"
  value       = var.cloud_provider == "aws" || var.cloud_provider == "multi" ? module.aws[0].vpc_id : null
}

output "subnet_ids" {
  description = "AWS Subnet IDs (if using AWS)"
  value       = var.cloud_provider == "aws" || var.cloud_provider == "multi" ? module.aws[0].subnet_ids : []
}
