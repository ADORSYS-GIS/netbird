# =============================================================================
# Database Configuration for NetBird
# Supports both Cloud SQL (PostgreSQL) and SQLite
# =============================================================================

# Cloud SQL Instance (PostgreSQL) - Only created if db_type is postgres AND create_db is true AND no external_db_dsn is provided
resource "google_sql_database_instance" "netbird_db" {
  count            = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? 1 : 0
  name             = "netbird-mgmt-db-${random_id.db_suffix[0].hex}"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = var.db_instance_tier
    availability_type = "REGIONAL"
    disk_size         = 20
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "04:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      # [SECURITY] For production, you MUST use private IP with VPC peering.
      # Using public IP with 0.0.0.0/0 is extremely insecure and only for initial setup.
      # private_network = data.google_compute_network.default.id

      authorized_networks {
        name  = "initial-setup" # WARNING: Restrict this to your specific IP or use Private IP
        value = "0.0.0.0/0"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}

# Random suffix for Cloud SQL instance name (to avoid conflicts on recreation)
resource "random_id" "db_suffix" {
  count       = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? 1 : 0
  byte_length = 4
}

# Database
resource "google_sql_database" "netbird" {
  count    = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? 1 : 0
  name     = "netbird"
  instance = google_sql_database_instance.netbird_db[0].name
}

# Database User
resource "google_sql_user" "netbird" {
  count    = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? 1 : 0
  name     = "netbird_admin"
  instance = google_sql_database_instance.netbird_db[0].name
  password = var.db_password
}

# =============================================================================
# Kubernetes Secret for NetBird
# Contains all sensitive configuration
# =============================================================================

resource "kubernetes_secret" "netbird_secrets" {
  metadata {
    name      = "netbird-secrets"
    namespace = kubernetes_namespace.netbird.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "netbird"
      "app.kubernetes.io/component"  = "secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    # If external_db_dsn is provided, use it.
    # Otherwise, if db_type is postgres and create_db is true, build the Cloud SQL DSN.
    # Otherwise, default to empty (SQLite).
    dsn = var.external_db_dsn != "" ? var.external_db_dsn : (
      (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? 
      "postgresql://${google_sql_user.netbird[0].name}:${google_sql_user.netbird[0].password}@${google_sql_database_instance.netbird_db[0].public_ip_address}:5432/${google_sql_database.netbird[0].name}?sslmode=disable" : 
      ""
    )

    # Keycloak Backend Client Secret
    idp_client_secret = keycloak_openid_client.netbird_backend.client_secret

    # Management Encryption Key (for encrypting sensitive data in DB)
    datastore_encryption_key = local.encryption_key

    # Relay/TURN authentication secret
    relay_password = local.relay_password
    turn_secret    = local.relay_password
  }

  type = "Opaque"
}

# =============================================================================
# Outputs
# =============================================================================

output "database_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? google_sql_database_instance.netbird_db[0].connection_name : (var.external_db_dsn != "" ? "External" : (var.db_type == "sqlite" ? "SQLite" : "Existing Postgres"))
  sensitive   = true
}

output "database_public_ip" {
  description = "Cloud SQL instance public IP"
  value       = (var.db_type == "postgres" && var.create_db && var.external_db_dsn == "") ? google_sql_database_instance.netbird_db[0].public_ip_address : (var.external_db_dsn != "" ? "External" : (var.db_type == "sqlite" ? "N/A" : "Existing Postgres"))
  sensitive   = true
}
