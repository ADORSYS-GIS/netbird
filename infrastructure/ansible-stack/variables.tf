variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "netbird_hosts" {
  description = "Map of hosts for NetBird deployment"
  type = map(object({
    public_ip  = string
    private_ip = optional(string)
    roles      = list(string) # ["management", "relay", "proxy"]
    ssh_user   = optional(string, "ubuntu")
  }))
}

# Database Configuration
variable "database_type" {
  description = "Database type (sqlite, postgresql)"
  type        = string
  default     = "sqlite"
}

variable "database_mode" {
  description = "Database mode (create, existing)"
  type        = string
  default     = "existing"
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

# PostgreSQL Create Configuration
variable "cloud_provider" {
  description = "Cloud provider for managed PostgreSQL (aws, gcp, azure)"
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

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "keycloak_admin_username" {
  description = "Keycloak Administrator Username"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak Administrator Password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_client_secret" {
  description = "Keycloak Admin Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "keycloak_use_existing_realm" {
  description = "Whether to use an existing Keycloak realm instead of creating a new one"
  type        = bool
  default     = false
}

variable "realm_name" {
  description = "Keycloak Realm Name"
  type        = string
  default     = "netbird"
}

variable "netbird_domain" {
  description = "NetBird Domain"
  type        = string
}

variable "netbird_version" {
  description = "NetBird Version"
  type        = string
  default     = "latest"
}

variable "caddy_version" {
  description = "Caddy Version"
  type        = string
  default     = "latest"
}

variable "docker_compose_version" {
  description = "Docker Compose Version"
  type        = string
  default     = "v2.24.0"
}


variable "netbird_log_level" {
  description = "Log level for NetBird services"
  type        = string
  default     = "info"
}

variable "relay_auth_secret" {
  description = "Relay Authentication Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "netbird_admin_email" {
  description = "Default NetBird admin email"
  type        = string
  default     = "admin@netbird.io"
}

variable "netbird_admin_password" {
  description = "Default NetBird admin password"
  type        = string
  sensitive   = true
}

# SSH Configuration
variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = ""
}

variable "netbird_encryption_key" {
  description = "32-byte encryption key for sensitive data at rest"
  type        = string
  default     = ""
  sensitive   = true
}
