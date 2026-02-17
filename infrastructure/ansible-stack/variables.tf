variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
  default     = {}
}

variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "gcp_label_filters" {
  description = "Labels to filter instances by"
  type        = map(string)
  default     = {}
}

variable "azure_resource_group" {
  description = "Azure Resource Group"
  type        = string
  default     = ""
}

variable "azure_tag_filters" {
  description = "Tags to filter instances by"
  type        = map(string)
  default     = {}
}

variable "azure_location" {
  description = "Azure Location"
  type        = string
  default     = "eastus"
}

variable "azure_vnet_name" {
  description = "Azure VNet Name"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "AWS VPC Name"
  type        = string
  default     = ""
}

variable "gcp_network_name" {
  description = "GCP Network Name"
  type        = string
  default     = ""
}

variable "manual_hosts" {
  description = "List of manual hosts"
  type        = list(any)
  default     = []
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = ""
}

# Database Configuration
variable "database_type" {
  description = "Database type (sqlite, postgresql, mysql)"
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
variable "postgresql_cloud_provider" {
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

# MySQL Existing Configuration
variable "existing_mysql_host" {
  description = "Existing MySQL host"
  type        = string
  default     = ""
}

variable "existing_mysql_port" {
  description = "Existing MySQL port"
  type        = number
  default     = 3306
}

variable "existing_mysql_database" {
  description = "Existing MySQL database name"
  type        = string
  default     = ""
}

variable "existing_mysql_username" {
  description = "Existing MySQL username"
  type        = string
  default     = ""
}

variable "existing_mysql_password" {
  description = "Existing MySQL password"
  type        = string
  default     = ""
  sensitive   = true
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
  description = "Keycloak Admin Client Secret (Required if admin-cli is confidential)"
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

variable "coturn_password" {
  description = "CoTurn Authentication Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
variable "ssh_user" {
  description = "SSH user for Ansible connection"
  type        = string
  default     = "ubuntu"
}

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
