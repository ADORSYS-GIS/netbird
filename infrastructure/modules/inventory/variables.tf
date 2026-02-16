variable "cloud_provider" {
  description = "Cloud provider: aws, gcp, azure, or multi (for hybrid)"
  type        = string
  validation {
    condition     = contains(["aws", "gcp", "azure", "multi"], var.cloud_provider)
    error_message = "cloud_provider must be one of: aws, gcp, azure, multi"
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_tag_filters" {
  description = "AWS tags to filter instances"
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
  description = "GCP labels to filter instances"
  type        = map(string)
  default     = {}
}

variable "azure_resource_group" {
  description = "Azure Resource Group"
  type        = string
  default     = ""
}

variable "azure_tag_filters" {
  description = "Azure tags to filter instances"
  type        = map(string)
  default     = {}
}

variable "manual_hosts" {
  description = "Manually specified hosts"
  type = list(object({
    name       = string
    public_ip  = string
    private_ip = string
    role       = string
  }))
  default = []
}
