variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
  default     = {}
}

variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "gcp_label_filters" {
  description = "Labels to filter instances by"
  type        = map(string)
  default     = {}
}

variable "azure_resource_group" {
  description = "Azure Resource Group"
  type        = string
  default     = ""
}

variable "azure_tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
  default     = {}
}

variable "azure_location" {
  description = "Azure Location"
  type        = string
  default     = "eastus"
}

variable "azure_vnet_name" {
  description = "Azure VNet Name"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "AWS VPC Name"
  type        = string
  default     = ""
}

variable "gcp_network_name" {
  description = "GCP Network Name"
  type        = string
  default     = ""
}

variable "manual_hosts" {
  description = "List of manual hosts"
  type        = list(any)
  default     = []
}

variable "db_username" {
  description = "Database Username"
  type        = string
}

variable "db_password" {
  description = "Database Password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Database Instance Class"
  type        = string
}

variable "db_storage_gb" {
  description = "Database Storage in GB"
  type        = number
  default     = 20
}

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "keycloak_admin_client_id" {
  description = "Keycloak Admin Client ID"
  type        = string
}

variable "keycloak_admin_client_secret" {
  description = "Keycloak Admin Client Secret"
  type        = string
  sensitive   = true
}

variable "realm_name" {
  description = "Keycloak Realm Name"
  type        = string
  default     = "netbird"
}

variable "netbird_domain" {
  description = "NetBird Domain"
  type        = string
}

variable "netbird_version" {
  description = "NetBird Version"
  type        = string
  default     = "latest"
}

variable "relay_auth_secret" {
  description = "Relay Authentication Secret"
  type        = string
  sensitive   = true
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
