# =============================================================================
# NETBIRD TERRAFORM + ANSIBLE STACK - CONFIGURATION EXAMPLE
# =============================================================================
# Use this file as a template for your deployment.
# Copy it to 'terraform.tfvars' and update the values.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Environment & Network
# -----------------------------------------------------------------------------
environment     = "prod"
aws_region      = "us-east-1"
netbird_domain  = "vpn.example.com"

# -----------------------------------------------------------------------------
# 2. Inventory Configuration
# -----------------------------------------------------------------------------
# Map your servers to roles: management, relay, proxy
# For a single-node setup, assign all roles to one host.
netbird_hosts = {
  "netbird-main" = {
    public_ip  = "1.2.3.4"      # Public IP reachable by clients and Ansible
    private_ip = "10.0.0.1"    # Optional: Internal IP for inter-service communication
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"       # Default user for Ansible connection
  }
}

# -----------------------------------------------------------------------------
# 3. Database Selection
# -----------------------------------------------------------------------------

# --- OPTION A: SQLite (Simpler, local file) ---
database_type        = "sqlite"
sqlite_database_path = "/var/lib/netbird/store.db"

# --- OPTION B: Existing PostgreSQL (Recommended for production) ---
# database_type                  = "postgresql"
# database_mode                  = "existing"
# existing_postgresql_host       = "db.example.com"
# existing_postgresql_port       = 5432
# existing_postgresql_database   = "netbird"
# existing_postgresql_username   = "netbird_user"
# existing_postgresql_password   = "REPLACE_WITH_SECURE_PASSWORD"
# existing_postgresql_sslmode    = "require"

# --- OPTION C: Create Managed PostgreSQL (Cloud-native) ---
# database_type                    = "postgresql"
# database_mode                    = "create"
# cloud_provider                   = "aws" # options: aws, gcp, azure
# postgresql_instance_class        = "db.t3.medium"
# postgresql_storage_gb            = 20
# postgresql_database_name         = "netbird"
# postgresql_username              = "netbird_admin"
# postgresql_password              = "REPLACE_WITH_SECURE_PASSWORD"
# postgresql_multi_az              = false # set to true for high availability
# postgresql_backup_retention_days = 7

# -----------------------------------------------------------------------------
# 4. Identity Provider (Keycloak) Configuration
# -----------------------------------------------------------------------------
# NetBird requires an OIDC provider. This module configures a Keycloak realm.
keycloak_url                 = "https://keycloak.example.com"
keycloak_admin_username      = "admin"
keycloak_admin_password      = "REPLACE_WITH_KEYCLOAK_ADMIN_PASSWORD"
keycloak_use_existing_realm  = false
realm_name                   = "netbird"

# -----------------------------------------------------------------------------
# 5. NetBird Application Secrets
# -----------------------------------------------------------------------------
# Default NetBird Dashboard Administrator
netbird_admin_email          = "admin@example.com"
netbird_admin_password       = "REPLACE_WITH_SECURE_ADMIN_PASSWORD"

# Secrets generation:
# If left empty, Terraform will generate secure random strings automatically.
relay_auth_secret            = ""
netbird_encryption_key       = "" # 32-byte base64 key for sensitive data at rest
netbird_log_level            = "info"

# -----------------------------------------------------------------------------
# 6. Version Pinning
# -----------------------------------------------------------------------------
netbird_version              = "latest"
caddy_version                = "latest"
docker_compose_version       = "v2.24.0"

# -----------------------------------------------------------------------------
# 7. Ansible Connection Settings
# -----------------------------------------------------------------------------
# Path to the private key used to SSH into 'netbird_hosts'
ssh_private_key_path         = "~/.ssh/id_rsa"
