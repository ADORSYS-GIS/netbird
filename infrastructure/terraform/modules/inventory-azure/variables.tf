variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group" {
  description = "Azure resource group name"
  type        = string
}

variable "tag_key" {
  description = "Tag key to filter VMs"
  type        = string
}

variable "tag_values" {
  description = "Tag values to filter VMs"
  type        = list(string)
}

variable "ssh_user" {
  description = "SSH user for VMs"
  type        = string
  default     = "ubuntu"
}
