terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

module "aws" {
  source = "./providers/aws"
  count  = var.cloud_provider == "aws" || var.cloud_provider == "multi" ? 1 : 0

  region      = var.aws_region
  tag_filters = var.aws_tag_filters
}

module "gcp" {
  source = "./providers/gcp"
  count  = var.cloud_provider == "gcp" || var.cloud_provider == "multi" ? 1 : 0

  project       = var.gcp_project
  region        = var.gcp_region
  label_filters = var.gcp_label_filters
}

module "azure" {
  source = "./providers/azure"
  count  = var.cloud_provider == "azure" || var.cloud_provider == "multi" ? 1 : 0

  resource_group_name = var.azure_resource_group
  tag_filters         = var.azure_tag_filters
}

module "manual" {
  source = "./providers/manual"

  manual_hosts = var.manual_hosts
}

locals {
  all_instances = concat(
    var.cloud_provider == "aws" || var.cloud_provider == "multi" ? module.aws[0].instances : [],
    var.cloud_provider == "gcp" || var.cloud_provider == "multi" ? module.gcp[0].instances : [],
    var.cloud_provider == "azure" || var.cloud_provider == "multi" ? module.azure[0].instances : [],
    module.manual.instances
  )

  management_nodes    = [for i in local.all_instances : i if i.role == "management"]
  relay_nodes         = [for i in local.all_instances : i if i.role == "relay"]
  reverse_proxy_nodes = [for i in local.all_instances : i if i.role == "reverse-proxy"]
}
