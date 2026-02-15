# Cloud Provider Toggles
variable "use_aws" {
  description = "Enable AWS VM discovery"
  type        = bool
  default     = false
}

variable "use_gcp" {
  description = "Enable GCP VM discovery"
  type        = bool
  default     = false
}

variable "use_azure" {
  description = "Enable Azure VM discovery"
  type        = bool
  default     = false
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for VM discovery"
  type        = string
  default     = "us-east-1"
}

variable "aws_tag_key" {
  description = "AWS tag key to filter VMs (e.g., 'NetBirdRole')"
  type        = string
  default     = "NetBirdRole"
}

variable "aws_tag_values" {
  description = "AWS tag values to filter VMs (e.g., ['netbird-primary', 'netbird-relay'])"
  type        = list(string)
  default     = ["netbird-primary", "netbird-relay"]
}

variable "aws_ssh_user" {
  description = "SSH user for AWS instances"
  type        = string
  default     = "ubuntu"
}

# GCP Configuration
variable "gcp_project" {
  description = "GCP project ID for VM discovery"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region for VM discovery"
  type        = string
  default     = "us-central1"
}

variable "gcp_label_key" {
  description = "GCP label key to filter VMs (e.g., 'netbird-role')"
  type        = string
  default     = "netbird-role"
}

variable "gcp_label_values" {
  description = "GCP label values to filter VMs (e.g., ['netbird-primary', 'netbird-relay'])"
  type        = list(string)
  default     = ["netbird-primary", "netbird-relay"]
}

variable "gcp_ssh_user" {
  description = "SSH user for GCP instances"
  type        = string
  default     = "ubuntu"
}

# Azure Configuration
variable "azure_subscription_id" {
  description = "Azure subscription ID for VM discovery"
  type        = string
  default     = ""
}

variable "azure_resource_group" {
  description = "Azure resource group for VM discovery"
  type        = string
  default     = ""
}

variable "azure_tag_key" {
  description = "Azure tag key to filter VMs (e.g., 'NetBirdRole')"
  type        = string
  default     = "NetBirdRole"
}

variable "azure_tag_values" {
  description = "Azure tag values to filter VMs (e.g., ['netbird-primary', 'netbird-relay'])"
  type        = list(string)
  default     = ["netbird-primary", "netbird-relay"]
}

variable "azure_ssh_user" {
  description = "SSH user for Azure VMs"
  type        = string
  default     = "ubuntu"
}
