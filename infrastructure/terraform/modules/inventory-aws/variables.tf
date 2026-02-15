variable "region" {
  description = "AWS region for VM discovery"
  type        = string
}

variable "tag_key" {
  description = "Tag key to filter instances"
  type        = string
}

variable "tag_values" {
  description = "Tag values to filter instances"
  type        = list(string)
}

variable "ssh_user" {
  description = "SSH user for instances"
  type        = string
  default     = "ubuntu"
}
