output "all_instances" {
  description = "All defined instances"
  value       = local.instances
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
  description = "VPC ID (dummy for compatibility)"
  value       = null
}

output "subnet_ids" {
  description = "Subnet IDs (dummy for compatibility)"
  value       = []
}
