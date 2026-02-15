output "all_vms" {
  description = "All discovered VMs across cloud providers"
  value       = local.all_vms
}

output "netbird_primary_vms" {
  description = "VMs tagged as netbird-primary"
  value       = local.netbird_primary
}

output "netbird_relay_vms" {
  description = "VMs tagged as netbird-relay"
  value       = local.relay_servers
}

output "inventory_file_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}
