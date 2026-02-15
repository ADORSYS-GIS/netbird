# Note: Azure module uses external data source (az CLI)
# This requires az CLI to be installed and authenticated
# For a pure Terraform approach, you would need to know the VM names in advance

# Placeholder for Azure VMs - users should populate this via external data source
# or by maintaining a list of known VM names in terraform.tfvars

locals {
  # Placeholder for VMs - users should populate this via external data source
  vms = []

  # Example of how to use external data source (requires az CLI):
  # Uncomment and use if az CLI is available:
  # vms_json = jsondecode(data.external.azure_vms.result.vms)
  # vms = [for vm in local.vms_json : {
  #   name        = vm.name
  #   public_ip   = vm.public_ip
  #   private_ip  = vm.private_ip
  #   ssh_user    = var.ssh_user
  #   roles       = [vm.role]
  #   cloud       = "azure"
  #   region      = vm.location
  #   instance_id = vm.name
  # }]
}

# Uncomment to use az CLI for discovery (requires az CLI installed):
# data "external" "azure_vms" {
#   program = ["bash", "${path.module}/scripts/discover_azure_vms.sh"]
#   query = {
#     subscription_id = var.subscription_id
#     resource_group  = var.resource_group
#     tag_key         = var.tag_key
#   }
# }
