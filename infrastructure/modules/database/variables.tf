variable "database_type" {
  description = "Database type (sqlite, postgresql)"
  type        = string
  validation {
    condition     = contains(["sqlite", "postgresql"], var.database_type)
    error_message = "database_type must be one of: sqlite, postgresql"
  }
}

variable "database_mode" {
  description = "Database mode (only 'existing' is supported)"
  type        = string
  validation {
    condition     = contains(["existing"], var.database_mode)
    error_message = "database_mode must be 'existing'"
  }
}

variable "enable_ha" {
  description = "Enable High Availability features"
  type        = bool
  default     = false
}

# SQLite Configuration
variable "sqlite_database_path" {
  description = "Path for SQLite database file"
  type        = string
  default     = "/var/lib/netbird/store.db"
}

# PostgreSQL Existing Configuration
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

variable "existing_postgresql_channel_binding" {
  description = "PostgreSQL channel binding mode (disable, prefer, require)"
  type        = string
  default     = "prefer"
}
