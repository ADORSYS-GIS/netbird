# =============================================================================
# NETBIRD MULTI-NODE HIGH AVAILABILITY - COMPLETE CONFIGURATION REFERENCE
# =============================================================================
#
# This file contains ALL 48 configuration variables for NetBird HA.
# Variables marked [REQUIRED] MUST be set before deployment.
# All other variables have sensible defaults shown below.
#
# COPY & USE:
#   cp multinoded.tfvars.example terraform.tfvars
#   vim terraform.tfvars  (update ALL [REQUIRED] values)
#   terraform plan && terraform apply
#
# =============================================================================

# =============================================================================
# SECTION 1: CORE CONFIGURATION [REQUIRED]
# =============================================================================

netbird_domain = "your-domain.com" # [REQUIRED] Your domain name

environment = "prod" # Environment: prod, staging, dev

# [REQUIRED] Multi-node host configuration
# Define dedicated nodes (each node runs all roles: management, relay, proxy)
netbird_hosts = {
  # HA Cluster Nodes (3 for quorum-based clustering)
  # Each node runs: management + relay + proxy services + PgBouncer
  "node-1" = {
    public_ip  = "YOUR.PUBLIC.IP.1"
    private_ip = "YOUR.PRIVATE.IP.1"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
  "node-2" = {
    public_ip  = "YOUR.PUBLIC.IP.2"
    private_ip = "YOUR.PRIVATE.IP.2"
    roles      = ["management", "relay", "proxy"]
    ssh_user   = "ubuntu"
  }
  "node-3" = {
    public_ip  = "YOUR.PUBLIC.IP.3"
    private_ip = "YOUR.PRIVATE.IP.3"
    roles      = ["management", "relay"]
    ssh_user   = "ubuntu"
  }
}

# =============================================================================
# SECTION 2: DATABASE CONFIGURATION [REQUIRED]
# =============================================================================
# For HA deployments, you MUST use an external PostgreSQL database
# with Multi-AZ failover capability

database_type = "postgresql"
database_mode = "existing"
enable_ha     = true

# [REQUIRED] PostgreSQL database (AWS RDS, Azure, GCP, or self-hosted)
existing_postgresql_host     = "your-db-host.region.aws.rds.amazonaws.com"  # Database endpoint
existing_postgresql_port     = 5432
existing_postgresql_database = "netbird_db"
existing_postgresql_username = "netbird_user"
existing_postgresql_password = "CHANGE_ME_STRONG_PASSWORD" # [REQUIRED] Set via environment variable: TF_VAR_existing_postgresql_password
existing_postgresql_sslmode  = "require"  # TLS encryption for DB connection

# SQLite is NOT recommended for HA deployments (only for single-node)
# sqlite_database_path = "/var/lib/netbird/store.db"

# =============================================================================
# SECTION 3: KEYCLOAK / IDENTITY PROVIDER [REQUIRED]
# =============================================================================

keycloak_url                 = "https://keycloak.your-domain.com/auth" # [REQUIRED] Keycloak server URL
keycloak_admin_username      = "admin"
keycloak_admin_password      = "CHANGE_ME_STRONG_PASSWORD" # [REQUIRED] Set via environment variable: TF_VAR_keycloak_admin_password
keycloak_admin_client_secret = "CHANGE_ME_KEYCLOAK_SECRET" # Set via environment variable: TF_VAR_keycloak_admin_client_secret
keycloak_use_existing_realm  = true
realm_name                   = "netbird"

# =============================================================================
# SECTION 4: APPLICATION SECRETS & CREDENTIALS [REQUIRED FOR HA]
# =============================================================================
# ⚠️ CRITICAL FOR HA: Set permanent values for these secrets!
# If these secrets change on terraform re-apply, all clients will lose connectivity.
#
# To generate secure values:
#   openssl rand -base64 32
#
# Steps:
# 1. Generate 32-byte secrets using command above
# 2. Uncomment lines below and paste your generated values
# 3. Apply once: terraform apply
# 4. NEVER CHANGE these values again (unless you want clients to reconnect)

netbird_admin_email    = "admin@your-domain.com" # [REQUIRED]
netbird_admin_password = "CHANGE_ME_STRONG_PASSWORD" # [REQUIRED] Set via environment variable: TF_VAR_netbird_admin_password

# [REQUIRED for HA] Permanent secrets that MUST NOT change between applies
# If these change, all connected clients will lose connectivity
# Generate using: openssl rand -hex 32
# Store in environment variables or CI/CD secrets:
#   TF_VAR_relay_auth_secret
#   TF_VAR_netbird_encryption_key
relay_auth_secret      = "CHANGE_ME_OPENSSL_RAND_HEX_32"
netbird_encryption_key = "CHANGE_ME_OPENSSL_RAND_HEX_32"

# =============================================================================
# SECTION 5: VERSION CONFIGURATION
# =============================================================================

netbird_version        = "latest" # NetBird version to deploy (e.g., "1.0.0" or "latest")
caddy_version          = "2.11"
haproxy_version        = "3.2.0"
coturn_version         = "latest"
docker_compose_version = "v5.0.2"

# =============================================================================
# SECTION 6: REVERSE PROXY & CERTIFICATE CONFIGURATION (HAPROXY + ACME)
# =============================================================================
# Direct HAProxy with built-in ACME support (minimal latency, no middleman)
#   - HAProxy (port 443): TLS termination + Load balancing + ACME certificates
#   - Uses: ghcr.io/flobernd/haproxy-acme-http01 (HAProxy with ACME built-in)
#   Flow: Client → HAProxy (443) → Management Nodes (no extra hops!)

proxy_type    = "haproxy"                     # HAProxy with ACME support
acme_provider = "letsencrypt"                 # ACME provider: letsencrypt only
acme_email    = "admin@your-domain.com"       # Email for certificate notifications

# HAProxy ACME Configuration
# Uses HTTP-01 challenge (port 80 must be accessible)
# Automatic certificate renewal via cron

# =============================================================================
# SECTION 7: LOGGING CONFIGURATION
# =============================================================================

netbird_log_level = "info" # Options: debug, info, warn, error

# =============================================================================
# SECTION 8: SSH / ANSIBLE CONFIGURATION [REQUIRED]
# =============================================================================

ssh_private_key_path = "~/.ssh/your-key-name"  # [REQUIRED] Path to SSH private key for node access

# =============================================================================
# SECTION 9: HIGH AVAILABILITY CONFIGURATION [CRITICAL]
# =============================================================================
# ⚠️ ALL OF THESE MUST BE ENABLED FOR HA TO WORK
# Disabling any of these will break HA functionality

# Feature 1: Management Service Clustering
enable_clustering    = true # MUST be true for HA
netbird_cluster_port = 9090 # Port for inter-node communication

# Feature 2: PgBouncer Connection Pooling
# CRITICAL: Prevents database connection exhaustion with multiple nodes
enable_pgbouncer               = true
pgbouncer_listen_port          = 6432
pgbouncer_min_pool_size        = 10 # Minimum idle connections
pgbouncer_default_pool_size    = 25 # Target pool size (tuned for 3 mgmt nodes)
pgbouncer_reserve_pool_size    = 5  # Extra connections for spikes
pgbouncer_reserve_pool_timeout = 3
pgbouncer_pool_mode            = "transaction" # Transaction-level pooling

# =============================================================================
# SECTION 10: HAPROXY HEALTH CHECK CONFIGURATION [CRITICAL]
# =============================================================================
# CRITICAL: Controls how quickly failed nodes are detected and removed
# These settings enable automatic failover within 15 seconds

haproxy_health_check_interval = 5000   # milliseconds: check every 5s
haproxy_health_check_timeout  = 3000   # milliseconds: max 3s response time
haproxy_health_check_fall     = 2      # consecutive failures before marking DOWN
haproxy_health_check_rise     = 3      # consecutive successes before marking UP
haproxy_stick_table_size      = "100k" # Max sessions per stick table
haproxy_stick_table_expire    = "30m"  # Session timeout

# =============================================================================
# SECTION 11: MULTI-NODE HA DEPLOYMENT NOTES
# =============================================================================
#
# ✓ Typical HA Architecture:
#   - 3 management nodes (for quorum-based clustering)
#   - 2+ relay nodes (optional, for load distribution)
#   - 2+ proxy nodes (for reverse proxy failover)
#   - 1 external PostgreSQL database (Multi-AZ)
#
# ✓ What gets deployed:
#   - NetBird management service (3 nodes)
#   - NetBird signal server (3 nodes)
#   - NetBird dashboard (3 nodes)
#   - COTURN STUN/TURN servers (3 nodes)
#   - PgBouncer connection pooler (on management nodes)
#   - HAProxy load balancer (2 nodes)
#   - Caddy reverse proxy (2 nodes)
#   - External PostgreSQL database (Multi-AZ, automated backups)
#
# ✓ What you get with HA:
#   - Automatic failover (<15 seconds)
#   - Zero-downtime rolling updates
#   - Load balanced across all nodes
#   - Session persistence (sticky sessions)
#   - Connection pooling (prevents DB exhaustion)
#   - Inter-node state synchronization (clustering)
#   - Health monitoring and auto-recovery
#
# ✓ Suitable for:
#   - Production deployments (100-5000+ users)
#   - Mission-critical setups
#   - High availability requirements
#   - Geographic distribution
#
# ✓ Resource requirements per node:
#   - CPU: 2+ vCPUs (4+ recommended)
#   - RAM: 4-8 GB
#   - Disk: 20-50 GB
#   - Network: 10+ Mbps
#
# ✓ Database requirements:
#   - PostgreSQL 12+ (external, not managed by Terraform)
#   - Multi-AZ failover capability (AWS RDS, Azure, GCP)
#   - Automated daily backups
#   - At least 2 nodes for failover
#
# ✓ Critical configuration for HA:
#   1. relay_auth_secret: MUST BE PERMANENT (same on all applies)
#   2. netbird_encryption_key: MUST BE PERMANENT (same on all applies)
#   3. enable_clustering = true: Inter-node communication enabled
#   4. enable_pgbouncer = true: Connection pooling prevents exhaustion
#   5. All health check settings: Enable automatic failover
#   6. Sticky sessions: Keep gRPC/WebSocket connections stable
#
# ✓ Firewall rules needed (between nodes):
#   - 9090/tcp (inter-node clustering)
#   - 6432/tcp (PgBouncer connection pooling)
#   - All external ports (80, 443, 3478, 33080)
#
# ✓ SSL certificates:
#   - Caddy on proxy nodes obtains/renews Let's Encrypt certificates
#   - One certificate per proxy node
#   - Automatic renewal in background
#
# ✓ Backup strategy:
#   - Database: Automated daily snapshots (30-day retention)
#   - Configuration: Stored in Git with Terraform state
#   - Restore tested quarterly
#
# ✓ Monitoring:
#   - HAProxy stats: http://proxy-node:8404/stats
#   - Health check: curl -f https://netbird.example.com/health
#   - Database: SELECT count(*) FROM users
#   - PgBouncer: SHOW POOLS (via PgBouncer CLI)
#
# ✓ Scaling:
#   - Add management nodes: Increase count in netbird_hosts
#   - Add relay nodes: Increases throughput
#   - Add proxy nodes: Increases failover redundancy
#   - Each node uses clustering for auto-discovery
#
# ✓ Testing failover:
#   docker stop netbird-management-1  # Kill one node
#   curl -f https://netbird.example.com/health  # Should still work
#   HAProxy routes around the failed node automatically
#
# ✓ Common issues & solutions:
#   - DB connection exhausted: Increase pgbouncer_default_pool_size
#   - gRPC connections drop: Check haproxy_stick_table_* settings
#   - Nodes not clustering: Verify port 9090 firewall rules
#   - Secret mismatch: Ensure relay_auth_secret is permanent
#   - Certificates failing: Verify domain DNS resolves
#
# =============================================================================
