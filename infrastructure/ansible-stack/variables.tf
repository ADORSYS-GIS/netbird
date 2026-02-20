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
  description = "Database mode ('existing' recommended)"
  type        = string
  default     = "existing"
  validation {
    condition     = contains(["existing"], var.database_mode)
    error_message = "database_mode must be 'existing'."
  }
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

variable "proxy_type" {
  description = "Reverse proxy type: 'caddy' (default) or 'haproxy'"
  type        = string
  default     = "caddy"
  validation {
    condition     = contains(["caddy", "haproxy"], var.proxy_type)
    error_message = "proxy_type must be either 'caddy' or 'haproxy'."
  }
}

variable "haproxy_version" {
  description = "HAProxy Version"
  type        = string
  default     = "latest"
}

variable "acme_provider" {
  description = "ACME provider for Caddy certificates (letsencrypt or zerossl)"
  type        = string
  default     = "letsencrypt"
  validation {
    condition     = contains(["letsencrypt", "zerossl"], var.acme_provider)
    error_message = "acme_provider must be either 'letsencrypt' or 'zerossl'."
  }
}

variable "acme_email" {
  description = "Email address for ACME registration"
  type        = string
  default     = "admin@example.com"
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
# HA CONFIGURATION (Critical for Multi-Node Deployments)
# -----------------------------------------------------------------------------

variable "enable_clustering" {
  description = "Enable management service clustering for state synchronization"
  type        = bool
  default     = false
}

variable "netbird_cluster_port" {
  description = "Port for inter-node clustering communication"
  type        = number
  default     = 9090
}

variable "enable_pgbouncer" {
  description = "Enable PgBouncer connection pooler between management and database"
  type        = bool
  default     = false
}

variable "pgbouncer_listen_port" {
  description = "Port for PgBouncer to listen on"
  type        = number
  default     = 6432
}

variable "pgbouncer_min_pool_size" {
  description = "Minimum pool size for PgBouncer"
  type        = number
  default     = 10
}

variable "pgbouncer_default_pool_size" {
  description = "Default pool size for PgBouncer (tuned for 2-3 management nodes)"
  type        = number
  default     = 25
}

variable "pgbouncer_reserve_pool_size" {
  description = "Reserve pool size for PgBouncer"
  type        = number
  default     = 5
}

variable "pgbouncer_reserve_pool_timeout" {
  description = "Timeout for reserve pool in seconds"
  type        = number
  default     = 3
}

variable "pgbouncer_pool_mode" {
  description = "PgBouncer pool mode (transaction, session, or statement)"
  type        = string
  default     = "transaction"
  validation {
    condition     = contains(["transaction", "session", "statement"], var.pgbouncer_pool_mode)
    error_message = "pgbouncer_pool_mode must be 'transaction', 'session', or 'statement'."
  }
}

variable "haproxy_health_check_interval" {
  description = "HAProxy health check interval in milliseconds"
  type        = number
  default     = 5000
}

variable "haproxy_health_check_timeout" {
  description = "HAProxy health check timeout in milliseconds"
  type        = number
  default     = 3000
}

variable "haproxy_health_check_fall" {
  description = "Number of consecutive failures before marking backend down"
  type        = number
  default     = 2
}

variable "haproxy_health_check_rise" {
  description = "Number of consecutive successes before marking backend up"
  type        = number
  default     = 3
}

variable "haproxy_stick_table_size" {
  description = "HAProxy stick table size for session persistence"
  type        = string
  default     = "100k"
}

variable "haproxy_stick_table_expire" {
  description = "HAProxy stick table entry expiration time"
  type        = string
  default     = "30m"
}

# -----------------------------------------------------------------------------
# SSH / ANSIBLE
# -----------------------------------------------------------------------------

variable "ssh_private_key_path" {
  description = "Local path to the SSH private key for host access"
  type        = string
}
