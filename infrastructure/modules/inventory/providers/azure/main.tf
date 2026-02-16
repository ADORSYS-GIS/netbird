data "azurerm_resources" "netbird_vms" {
  resource_group_name = var.resource_group_name
  type                = "Microsoft.Compute/virtualMachines"

  required_tags = var.tag_filters
}

data "azurerm_virtual_machine" "details" {
  for_each            = { for r in data.azurerm_resources.netbird_vms.resources : r.name => r }
  name                = each.value.name
  resource_group_name = split("/", each.value.id)[4]
}

locals {
  instances = [
    for vm in data.azurerm_virtual_machine.details : {
      name       = vm.name
      private_ip = vm.private_ip_address
      public_ip  = length(vm.public_ip_addresses) > 0 ? vm.public_ip_addresses[0] : ""
      role       = try(vm.tags["Role"], "")
    }
  ]
}
