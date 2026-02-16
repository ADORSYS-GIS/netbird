variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region (unused for instance lookup but good for context)"
  type        = string
}

variable "label_filters" {
  description = "Labels to filter instances by (currently unused in simple implementation)"
  type        = map(string)
  default     = {} 
}
