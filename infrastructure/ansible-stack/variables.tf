# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "netbird_domain" {
  description = "Public domain name for NetBird"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "netbird_hosts" {
  description = "Map of target hosts. Format: hostname = { public_ip, private_ip?, roles, ssh_user? }"
  type = map(object({
    public_ip  = string
    private_ip = optional(string)
    roles      = list(string) # ["management", "relay", "proxy"]
    ssh_user   = optional(string, "ubuntu")
  }))
}

# -----------------------------------------------------------------------------
# DATABASE CONFIGURATION
# -----------------------------------------------------------------------------

variable "database_type" {
  description = "Database backend: 'sqlite' or 'postgresql'"
  type        = string
  default     = "sqlite"
}

variable "database_mode" {
  description = "For postgresql: 'create' (managed cloud DB) or 'existing'"
  type        = string
  default     = "existing"
}

variable "enable_ha" {
  description = "Enable HA features (like multiple management nodes)"
  type        = bool
  default     = false
}

# SQLite specific
variable "sqlite_database_path" {
  description = "Path for SQLite DB on the management server"
  type        = string
  default     = "/var/lib/netbird/store.db"
}

# Managed PostgreSQL (Used only if database_mode = 'create')
variable "cloud_provider" {
  description = "Target cloud for managed DB (aws, gcp, azure)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS Region (only needed if provider 'aws' is actively used)"
  type        = string
  default     = "us-east-1"
}

variable "postgresql_instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "postgresql_storage_gb" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "postgresql_database_name" {
  description = "DB name"
  type        = string
  default     = "netbird"
}

variable "postgresql_username" {
  description = "DB master username"
  type        = string
  default     = "netbird"
}

variable "postgresql_password" {
  description = "DB master password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_multi_az" {
  description = "Enable DB HA"
  type        = bool
  default     = true
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention"
  type        = number
  default     = 7
}

# Existing PostgreSQL (Used only if database_mode = 'existing')
variable "existing_postgresql_host" {
  description = "DB Host"
  type        = string
  default     = ""
}

variable "existing_postgresql_port" {
  description = "DB Port"
  type        = number
  default     = 5432
}

variable "existing_postgresql_database" {
  description = "DB Name"
  type        = string
  default     = ""
}

variable "existing_postgresql_username" {
  description = "DB Username"
  type        = string
  default     = ""
}

variable "existing_postgresql_password" {
  description = "DB Password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "existing_postgresql_sslmode" {
  description = "PostgreSQL SSL mode"
  type        = string
  default     = "require"
}

# -----------------------------------------------------------------------------
# IDENTITY PROVIDER (KEYCLOAK)
# -----------------------------------------------------------------------------

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_client_secret" {
  description = "Keycloak client secret for admin-cli"
  type        = string
  default     = null
  sensitive   = true
}

variable "keycloak_use_existing_realm" {
  description = "Use an existing realm"
  type        = bool
  default     = false
}

variable "realm_name" {
  description = "NetBird realm name"
  type        = string
  default     = "netbird"
}

# -----------------------------------------------------------------------------
# APPLICATION SECRETS & VERSIONS
# -----------------------------------------------------------------------------

variable "netbird_admin_email" {
  description = "Default NetBird admin email"
  type        = string
}

variable "netbird_admin_password" {
  description = "Default NetBird admin password"
  type        = string
  sensitive   = true
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

variable "coturn_version" {
  description = "Coturn Version"
  type        = string
  default     = "latest"
}

variable "docker_compose_version" {
  description = "Docker Compose Version"
  type        = string
  default     = "v2.24.0"
}

variable "netbird_log_level" {
  description = "Log level"
  type        = string
  default     = "info"
}

variable "relay_auth_secret" {
  description = "Relay Secret (Generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "netbird_encryption_key" {
  description = "32-byte Encryption Key (Generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SSH / ANSIBLE
# -----------------------------------------------------------------------------

variable "ssh_private_key_path" {
  description = "Local path to the SSH private key for host access"
  type        = string
}
