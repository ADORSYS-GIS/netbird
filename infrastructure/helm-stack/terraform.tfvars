# =============================================================================
# NetBird Terraform Configuration
# =============================================================================

# GCP Configuration
project_id   = "observe-472521"
region       = "europe-west3"
cluster_name = "observe-prod-cluster"

# NetBird Domain
netbird_domain = "netbird.net.observe.camer.digital"

# Keycloak Configuration
keycloak_url        = "https://keycloak.observe.camer.digital"
keycloak_realm      = "netbird3"
keycloak_admin_user = "admin"
# IMPORTANT: Move this to a .tfvars.secret file or use environment variable
keycloak_admin_password = "admin_password"
keycloak_admin_client_secret = "O9w0jF65Nn1DAa6iLp4H0CK3FGIwS3jL"

# Keycloak Client IDs (following official docs naming)
keycloak_client_id      = "netbird-dashboard"
keycloak_mgmt_client_id = "netbird-backend"

# Let's Encrypt Configuration
letsencrypt_email = "rjagoum@gmail.com"

# Database Configuration
# db_type: Type of database ('sqlite' or 'postgres')
# create_db: Whether to create a new database instance (true) or use an existing one (false)
db_type   = "postgres"
create_db = false
external_db_dsn  = "postgresql://neondb_owner:npg_JniRyf3F7NHU@ep-noisy-dew-agyd3m98-pooler.c-2.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
db_password      = "highly-secure-db-password"
db_instance_tier = "db-f1-micro"

# High Availability (use 1 for SQLite, 3+ for PostgreSQL)
replica_count = 1

# Namespace
namespace = "netbird"

# Encryption key (leave empty for auto-generation, or provide 32 char string)
management_database_encryption_key = ""

# Helm Chart Version
netbird_chart_version = "1.9.0"

# Infrastructure Toggles        
install_cert_manager  = false
install_ingress_nginx = false
create_cert_issuer    = true
ingress_class_name    = "nginx"
cert_issuer_name      = "letsencrypt-prod"

# Logging
log_level = "info"

# Metrics (Prometheus)
enable_metrics = false

# Relay/TURN
enable_relay = true
stun_servers = ["stun:stun.l.google.com:19302"]

# Optional: Initial Admin User
netbird_admin_email    = "emmanuelodon943@gmail.com"
netbird_admin_password = "ChangeMe123!"
                        
