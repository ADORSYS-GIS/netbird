variable "resource_group_name" {
  description = "Azure Resource Group Name"
  type        = string
}

variable "tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
  default     = {}
}
