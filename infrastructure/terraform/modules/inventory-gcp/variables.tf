variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for VM discovery"
  type        = string
}

variable "label_key" {
  description = "Label key to filter instances"
  type        = string
}

variable "label_values" {
  description = "Label values to filter instances"
  type        = list(string)
}

variable "ssh_user" {
  description = "SSH user for instances"
  type        = string
  default     = "ubuntu"
}
