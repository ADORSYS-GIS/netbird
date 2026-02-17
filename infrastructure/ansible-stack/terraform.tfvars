# ============================================
# DATABASE BACKEND SELECTION
# ============================================

# OPTION 1: SQLite (Single-Node Only)
# Simple, no external database required
# NOT suitable for HA multi-node deployments
database_type        = "sqlite"
database_mode        = "existing" # Always "existing" for SQLite
sqlite_database_path = "/var/lib/netbird/store.db"
enable_ha            = false # MUST be false for SQLite

# OPTION 2: PostgreSQL - Create New Managed Database
# Recommended for production HA deployments
# database_type = "postgresql"
# database_mode = "create"
# postgresql_cloud_provider = "aws"  # or "gcp", "azure"
# postgresql_instance_class = "db.t3.medium"
# postgresql_storage_gb = 100
# postgresql_database_name = "netbird"
# postgresql_username = "netbird"
# postgresql_password = "CHANGE_ME_TO_STRONG_PASSWORD"  # Generate with: openssl rand -base64 32
# postgresql_multi_az = true
# postgresql_backup_retention_days = 30
# enable_ha = true

# OPTION 3: PostgreSQL - Use Existing Database
# Connect to already deployed PostgreSQL instance
# database_type = "postgresql"
# database_mode = "existing"
# existing_postgresql_host = "postgres.example.com"
# existing_postgresql_port = 5432
# existing_postgresql_database = "netbird"
# existing_postgresql_username = "netbird"
# existing_postgresql_password = "YOUR_EXISTING_DB_PASSWORD"
# existing_postgresql_sslmode = "require"
# enable_ha = true

# OPTION 4: MySQL - Use Existing Database
# Connect to already deployed MySQL instance
# database_type = "mysql"
# database_mode = "existing"
# existing_mysql_host = "mysql.example.com"
# existing_mysql_port = 3306
# existing_mysql_database = "netbird"
# existing_mysql_username = "netbird"
# existing_mysql_password = "YOUR_EXISTING_DB_PASSWORD"
# enable_ha = true

# Common Variables
netbird_domain  = "vpn.example.com"
cloud_provider  = "aws"
environment     = "prod"
aws_region      = "eu-north-1"
aws_tag_filters = { "Name" = "netbird" }

# Keycloak Configuration
keycloak_url                 = "https://keycloak.example.com/auth"
keycloak_admin_username      = "admin"
keycloak_admin_password      = "CHANGE_ME"
keycloak_admin_client_secret = "CHANGE_ME"
keycloak_use_existing_realm  = false

# Authentication Secrets (Leave empty to generate automatically)
relay_auth_secret      = ""
coturn_password        = ""
netbird_encryption_key = ""
admin_cidr_blocks      = ["0.0.0.0/0"]
netbird_log_level      = "info"

# Default Administrator
netbird_admin_email    = "admin@example.com"
netbird_admin_password = "CHANGE_ME"

# SSH Configuration for Ansible
ssh_user             = "ubuntu"
ssh_private_key_path = "~/.ssh/private_key" # Update this to your local private key path
