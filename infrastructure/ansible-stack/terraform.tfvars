# NetBird Infrastructure Configuration
# Copy to terraform.tfvars and customize for your deployment

# Core Configuration
netbird_domain = "netbird-dev.observe.camer.digital"
environment    = "prod"

# Host definitions - define all servers and their roles
# Roles: "management" (API/signal), "relay" (peer connections), "proxy" (load balancer)
netbird_hosts = {
  # HA Cluster Nodes (3 for quorum-based clustering)
  # Each node runs: management + relay + proxy services + PgBouncer
  "node-1" = {
    public_ip  = "51.20.52.128"
    private_ip = "172.31.20.213"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
  "node-2" = {
    public_ip  = "16.171.59.171"
    private_ip = "172.31.4.141"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
  "node-3" = {
    public_ip  = "13.63.35.177"
    private_ip = "172.31.11.58"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
}

# Database Configuration
# Use PostgreSQL for production, SQLite only for development/testing
database_type = "postgresql"
database_mode = "existing"
enable_ha     = true # Enable for multi-node deployments

# PostgreSQL connection (required when database_type = "postgresql")
existing_postgresql_host            = "ep-mute-mode-aipe8ucx-pooler.c-4.us-east-1.aws.neon.tech"
existing_postgresql_port            = 5432
existing_postgresql_database        = "neondb"
existing_postgresql_username        = "neondb_owner"
existing_postgresql_password        = "npg_qLMck9Sj6rsX" # Use environment variable: TF_VAR_existing_postgresql_password
existing_postgresql_sslmode         = "require"
existing_postgresql_channel_binding = "require" # Options: disable, prefer, require (required for Neon)

# SQLite path (only used when database_type = "sqlite")
sqlite_database_path = "/var/lib/netbird/store.db"

# Identity Provider (Keycloak)
# Must be accessible from management nodes
keycloak_url                 = "https://keycloak.observe.camer.digital"
keycloak_admin_username      = "admin"
keycloak_admin_password      = "admin_password"                   # Use environment variable: TF_VAR_keycloak_admin_password
keycloak_admin_client_secret = "O9w0jF65Nn1DAa6iLp4H0CK3FGIwS3jL" # Optional, uses password auth if null
realm_name                   = "netbird"
keycloak_use_existing_realm  = false

# NetBird Application
netbird_version        = "latest"
netbird_log_level      = "info" # Options: debug, info, warn, error
netbird_admin_email    = "admin@example.com"
netbird_admin_password = "ChangMe123!" # Use environment variable: TF_VAR_netbird_admin_password

# Application Secrets
# Leave empty for auto-generation, or set permanent values for HA deployments
# WARNING: Changing these after deployment will disconnect all clients
relay_auth_secret      = "GHSYrIfC2OwAPYLRbJ2o5ZO0RzcaYonzPI1crYXG+1M=" # Generate with: openssl rand -base64 32
netbird_encryption_key = "uRzOR2zCY6zZbByqKnXhT3p2kM/4PBAMZnpVTO1foeI=" # Generate with: openssl rand -base64 32

# Reverse Proxy Configuration
# "caddy" for automatic HTTPS, "haproxy" for advanced load balancing
proxy_type      = "haproxy"
caddy_version   = "2.11"
haproxy_version = "3.2.0"

# ACME/TLS Configuration
# Certificates obtained automatically from Let's Encrypt
enable_acme             = true
acme_provider           = "letsencrypt" # Options: letsencrypt, zerossl
acme_email              = "onelsob57@gmail.com"
acme_account_thumbprint = "" # Leave empty for auto-detection (Ansible will register account and persist thumbprint to .acme_thumbprint file)

# HAProxy Health Checks
# Controls how quickly failed nodes are detected and removed from rotation
haproxy_health_check_interval = 5000 # Check every 5 seconds
haproxy_health_check_timeout  = 3000 # Wait up to 3 seconds for response
haproxy_health_check_fall     = 2    # Mark down after 2 failures
haproxy_health_check_rise     = 3    # Mark up after 3 successes

# HAProxy Session Persistence
# Keeps client connections to the same backend for gRPC/WebSocket stability
haproxy_stick_table_size   = "100k"
haproxy_stick_table_expire = "30m"
haproxy_stats_password     = "" # Leave empty for auto-generation

# Management Clustering
# Enables state synchronization between management nodes
enable_clustering    = false # Enable for multi-node management
netbird_cluster_port = 9090

# PgBouncer Connection Pooling
# Prevents database connection exhaustion with multiple management nodes
enable_pgbouncer               = true # Enable for PostgreSQL deployments
pgbouncer_listen_port          = 6432
pgbouncer_pool_mode            = "transaction" # Options: transaction, session, statement
pgbouncer_min_pool_size        = 10
pgbouncer_default_pool_size    = 25
pgbouncer_reserve_pool_size    = 5
pgbouncer_reserve_pool_timeout = 3
pgbouncer_max_client_conn      = 1000
pgbouncer_max_db_connections   = 100
pgbouncer_max_user_connections = 100
pgbouncer_server_lifetime      = 3600 # Seconds before recycling connections
pgbouncer_server_idle_timeout  = 600
pgbouncer_query_timeout        = 0 # 0 = disabled
pgbouncer_query_wait_timeout   = 120
pgbouncer_client_idle_timeout  = 0 # 0 = disabled
pgbouncer_stats_period         = 60
pgbouncer_health_check_period  = 10
pgbouncer_health_check_timeout = 5

# COTURN (STUN/TURN)
# Enables NAT traversal for peer connections
coturn_version  = "latest"
coturn_port     = 3478
coturn_min_port = 49152 # Relay port range start
coturn_max_port = 65535 # Relay port range end

# Container Versions
docker_compose_version = "v5.0.2"

# SSH Configuration
ssh_private_key_path = "~/.ssh/private_key"

# Deployment Automation
# Set to true to run Ansible automatically after Terraform apply
auto_deploy = true

# Deployment Scenarios:
#
# 1. Single-Node Development (Caddy + SQLite):
#    - Set proxy_type = "caddy"
#    - Set database_type = "sqlite"
#    - Set enable_haproxy_ha = false
#    - Set enable_clustering = false
#    - Set enable_pgbouncer = false
#    - Define 1 host with all roles
#
# 2. Single-Node Production (HAProxy + PostgreSQL):
#    - Set proxy_type = "haproxy"
#    - Set database_type = "postgresql"
#    - Set enable_haproxy_ha = false
#    - Set enable_clustering = false
#    - Set enable_pgbouncer = true
#    - Define 1 host with all roles
#
# 3. Multi-Node HA (HAProxy + PostgreSQL + Clustering):
#    - Set proxy_type = "haproxy"
#    - Set database_type = "postgresql"
#    - Set enable_clustering = true
#    - Set enable_pgbouncer = true
#    - Define 3+ management nodes
#    - Define 2+ proxy nodes
#    - Define 2+ relay nodes (optional)
#
# Security Notes:
# - Never commit terraform.tfvars to version control
# - Use environment variables for sensitive values (TF_VAR_*)
# - Generate strong secrets with: openssl rand -base64 32
# - Keep relay_auth_secret and netbird_encryption_key permanent in HA setups
#
# Network Requirements:
# - DNS must point to proxy public IP or load balancer
# - Firewall must allow: 80/tcp, 443/tcp, 3478/udp, 33080/tcp, 49152-65535/udp
# - Management nodes need access to database and Keycloak
# - Proxy nodes need access to management nodes
