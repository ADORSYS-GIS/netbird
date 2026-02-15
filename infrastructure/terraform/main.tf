# Configure cloud providers
provider "aws" {
  region = var.aws_region
  # Credentials loaded from environment variables or ~/.aws/credentials
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  # Credentials loaded from environment variable GOOGLE_APPLICATION_CREDENTIALS
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  # Credentials loaded from environment variables or Azure CLI
}

# Query VMs from enabled cloud providers
module "inventory_aws" {
  count  = var.use_aws ? 1 : 0
  source = "./modules/inventory-aws"

  region     = var.aws_region
  tag_key    = var.aws_tag_key
  tag_values = var.aws_tag_values
  ssh_user   = var.aws_ssh_user
}

module "inventory_gcp" {
  count  = var.use_gcp ? 1 : 0
  source = "./modules/inventory-gcp"

  project      = var.gcp_project
  region       = var.gcp_region
  label_key    = var.gcp_label_key
  label_values = var.gcp_label_values
  ssh_user     = var.gcp_ssh_user
}

module "inventory_azure" {
  count  = var.use_azure ? 1 : 0
  source = "./modules/inventory-azure"

  subscription_id = var.azure_subscription_id
  resource_group  = var.azure_resource_group
  tag_key         = var.azure_tag_key
  tag_values      = var.azure_tag_values
  ssh_user        = var.azure_ssh_user
}

# Combine all discovered VMs
locals {
  all_vms = concat(
    try(module.inventory_aws[0].vms, []),
    try(module.inventory_gcp[0].vms, []),
    try(module.inventory_azure[0].vms, [])
  )

  # Group VMs by role (based on tags/labels)
  netbird_primary = [for vm in local.all_vms : vm if contains(vm.roles, "netbird-primary")]
  relay_servers   = [for vm in local.all_vms : vm if contains(vm.roles, "netbird-relay")]
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../configuration/ansible/inventory/terraform_inventory.yaml"
  content = templatefile("${path.module}/templates/inventory.yaml.tpl", {
    netbird_primary = local.netbird_primary
    relay_servers   = local.relay_servers
  })
  file_permission = "0644"
}
