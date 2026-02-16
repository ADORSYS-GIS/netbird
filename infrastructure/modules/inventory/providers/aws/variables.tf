variable "region" {
  description = "AWS Region"
  type        = string
}

variable "tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
}
