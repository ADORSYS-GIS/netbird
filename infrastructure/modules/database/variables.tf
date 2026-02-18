variable "database_type" {
  description = "Database type (sqlite, postgresql)"
  type        = string
  validation {
    condition     = contains(["sqlite", "postgresql"], var.database_type)
    error_message = "database_type must be one of: sqlite, postgresql"
  }
}

variable "database_mode" {
  description = "Database mode (create, existing)"
  type        = string
  validation {
    condition     = contains(["create", "existing"], var.database_mode)
    error_message = "database_mode must be one of: create, existing"
  }
}

variable "enable_ha" {
  description = "Enable High Availability features"
  type        = bool
  default     = false
}

# SQLite
variable "sqlite_database_path" {
  description = "Path for SQLite database file"
  type        = string
  default     = "/var/lib/netbird/store.db"
}

# PostgreSQL Create
variable "cloud_provider" {
  description = "Cloud provider for managed PostgreSQL"
  type        = string
  default     = ""
}

variable "postgresql_instance_class" {
  description = "PostgreSQL instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "postgresql_storage_gb" {
  description = "PostgreSQL storage in GB"
  type        = number
  default     = 100
}

variable "postgresql_database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "netbird"
}

variable "postgresql_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "netbird"
}

variable "postgresql_password" {
  description = "PostgreSQL password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_multi_az" {
  description = "Enable PostgreSQL Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "postgresql_backup_retention_days" {
  description = "PostgreSQL backup retention in days"
  type        = number
  default     = 30
}

variable "vpc_id" {
  description = "VPC ID for managed DB"
  type        = string
  default     = ""
}

variable "database_subnet_ids" {
  description = "Subnet IDs for managed DB"
  type        = list(string)
  default     = []
}

variable "database_security_group_ids" {
  description = "Security group IDs for managed DB"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# PostgreSQL Existing
variable "existing_postgresql_host" {
  description = "Existing PostgreSQL host"
  type        = string
  default     = ""
}

variable "existing_postgresql_port" {
  description = "Existing PostgreSQL port"
  type        = number
  default     = 5432
}

variable "existing_postgresql_database" {
  description = "Existing PostgreSQL database name"
  type        = string
  default     = ""
}

variable "existing_postgresql_username" {
  description = "Existing PostgreSQL username"
  type        = string
  default     = ""
}

variable "existing_postgresql_password" {
  description = "Existing PostgreSQL password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "existing_postgresql_sslmode" {
  description = "Existing PostgreSQL SSL mode"
  type        = string
  default     = "require"
}
