variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
}

variable "instance_class" {
  description = "DB instance class/tier"
  type        = string
}

variable "storage_gb" {
  description = "Allocated storage in GB"
  type        = number
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "username" {
  description = "Database master username"
  type        = string
}

variable "password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable multi-AZ / high availability"
  type        = bool
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID for DB placement"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for DB placement"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for DB placement"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
