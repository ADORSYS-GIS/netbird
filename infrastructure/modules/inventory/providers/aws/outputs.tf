output "instances" {
  description = "Normalized list of instances"
  value       = local.instances
}

output "vpc_id" {
  description = "VPC ID of first discovered instance (for network context)"
  value       = length(local.instances) > 0 ? local.instances[0].vpc_id : null
}

output "subnet_ids" {
  description = "Unique subnet IDs from discovered instances"
  value       = distinct([for i in local.instances : i.subnet_id])
}
