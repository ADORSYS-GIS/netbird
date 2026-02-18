# ============================================
# NETBIRD DEPLOYMENT CONFIGURATION
# ============================================

# Define your hosts and their roles here
# Roles: management, relay, proxy
# For single-node deployment, assign all roles to one host
netbird_hosts = {
  "netbird-server" = {
    public_ip  = "1.2.3.4"
    private_ip = "10.0.0.1"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
}

# Database Backend Selection
database_type        = "sqlite"
database_mode        = "existing"
sqlite_database_path = "/var/lib/netbird/store.db"
enable_ha            = false

# Common Variables
netbird_domain  = "vpn.example.com"
environment     = "prod"

# Keycloak Configuration
keycloak_url                 = "https://keycloak.example.com/auth"
keycloak_admin_username      = "admin"
keycloak_admin_password      = "CHANGE_ME"
keycloak_use_existing_realm  = false

# Authentication Secrets (Leave empty to generate automatically)
relay_auth_secret      = ""
netbird_encryption_key = ""
netbird_log_level      = "info"

# Default Administrator
netbird_admin_email    = "admin@example.com"
netbird_admin_password = "CHANGE_ME"

# SSH Configuration for Ansible
ssh_private_key_path = "~/.ssh/id_rsa"
