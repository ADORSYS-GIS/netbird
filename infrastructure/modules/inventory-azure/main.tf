data "azurerm_resources" "netbird_vms" {
  resource_group_name = var.resource_group_name
  type                = "Microsoft.Compute/virtualMachines"
  
  required_tags = var.tag_filters
}

data "azurerm_virtual_machine" "details" {
  for_each            = { for r in data.azurerm_resources.netbird_vms.resources : r.name => r }
  name                = each.value.name
  resource_group_name = split("/", each.value.id)[4] # Extract RG from ID
}

output "instances" {
  value = [
    for vm in data.azurerm_virtual_machine.details : {
      hostname    = vm.name
      ip          = vm.private_ip_address
      # Allow Manual Override or Public IP lookup?
      # For now, Azure VMs might not have public IP directly attached but via NIC/PublicIP resource.
      # Simplified: assuming private access or user provides public IP in tags if needed.
      # Check if public IP exists
      public_ip   = length(vm.public_ip_addresses) > 0 ? vm.public_ip_addresses[0] : ""
      role        = try(vm.tags["NetBirdRole"], "unknown")
      cloud       = "azure"
      ssh_user    = "ubuntu"
      # Metadata
      location = vm.location
      id       = vm.id
      resource_group_name = vm.resource_group_name
    }
  ]
}
