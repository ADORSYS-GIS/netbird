# =============================================================================
# NETBIRD SINGLE-NODE DEPLOYMENT (DOCKER + SQLITE)
# =============================================================================
# Simplest possible configuration for testing or small-scale use.
# All roles (management, signal, dashboard, relay, proxy) on a single server.
# =============================================================================

# 1. Main Configuration
netbird_domain = "netbird.observe.camer.digital"
environment    = "dev"

# 2. Host Configuration (One VM for everything)
netbird_hosts = {
  "netbird-all-in-one" = {
    public_ip = "16.171.59.171"
    roles     = ["management", "relay", "proxy"] # Includes all NetBird services
    ssh_user  = "ubuntu"
  }
}

# 3. Database (SQLite is local to the server)
database_type        = "sqlite"
sqlite_database_path = "/var/lib/netbird/store.db"

# 4. Identity Provider (Keycloak)
keycloak_url                 = "https://keycloak.net.observe.camer.digital/auth"
keycloak_admin_username      = "admin"
keycloak_admin_password      = "password123!"
keycloak_admin_client_secret = "rk9v8yewnXKOZ1oAbXktyHIIUl7rDVob"
keycloak_use_existing_realm = true
realm_name = "netbird2"


# 5. NetBird Admin Dashboard
netbird_admin_email    = "admin@observe.camer.digital"
netbird_admin_password = "password123!"

# 6. ACME Configuration
acme_provider = "letsencrypt"
acme_email    = "admin@observe.camer.digital"

# 7. SSH Credentials for Ansible
ssh_private_key_path = "~/.ssh/private_key"
