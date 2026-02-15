# Note: GCP and Azure modules use external data sources (gcloud/az CLI)
# This requires gcloud CLI and az CLI to be installed and authenticated
# For a pure Terraform approach, consider using terraform-provider-google's
# google_compute_instance data source with a known list of instance names

# Discover running GCP Compute instances with specified labels
# Using a simplified approach that doesn't require external CLI tools
data "google_compute_zones" "available" {
  project = var.project
  region  = var.region
}

# Note: This is a placeholder - in production, you would either:
# 1. Use external data source with gcloud CLI (requires gcloud installed)
# 2. Maintain a list of known instance names
# 3. Use a custom script to query the GCP API
# For now, we'll use an empty list and document the requirement

locals {
  # Placeholder for VMs - users should populate this via external data source
  # or by maintaining a list of instance names in terraform.tfvars
  vms = []

  # Example of how to use external data source (requires gcloud CLI):
  # Uncomment and use if gcloud is available:
  # instances_json = jsondecode(data.external.gcp_instances.result.instances)
  # vms = [for instance in local.instances_json : {
  #   name        = instance.name
  #   public_ip   = instance.public_ip
  #   private_ip  = instance.private_ip
  #   ssh_user    = var.ssh_user
  #   roles       = [instance.role]
  #   cloud       = "gcp"
  #   region      = var.region
  #   instance_id = instance.name
  # }]
}

# Uncomment to use gcloud CLI for discovery (requires gcloud installed):
# data "external" "gcp_instances" {
#   program = ["bash", "${path.module}/scripts/discover_gcp_instances.sh"]
#   query = {
#     project    = var.project
#     region     = var.region
#     label_key  = var.label_key
#   }
# }
