# Cloud SQL Instance (PostgreSQL)
resource "google_sql_database_instance" "netbird_db" {
  count            = var.use_external_db ? 1 : 0
  name             = "netbird-mgmt-db"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier              = var.db_instance_tier
    availability_type = "REGIONAL" # High Availability

    backup_configuration {
      enabled    = true
      start_time = "04:00"
    }

    ip_configuration {
      ipv4_enabled    = true # Set to false if using private IP only with Service Networking
      # private_network = data.google_compute_network.default.id
    }
  }

  deletion_protection = true # Production grade
}

resource "google_sql_database" "netbird" {
  count    = var.use_external_db ? 1 : 0
  name     = "netbird"
  instance = google_sql_database_instance.netbird_db[0].name
}

resource "google_sql_user" "netbird" {
  count    = var.use_external_db ? 1 : 0
  name     = "netbird_admin"
  instance = google_sql_database_instance.netbird_db[0].name
  password = var.db_password
}

# Secret for database DSN
resource "kubernetes_secret" "database_dsn" {
  count = var.use_external_db ? 1 : 0
  metadata {
    name      = "netbird-db-dsn"
    namespace = kubernetes_namespace.netbird.metadata[0].name
  }

  data = {
    # host=<PG_HOST> user=<PG_USER> password=<PG_PASSWORD> dbname=<PG_DB_NAME> port=<PG_PORT> sslmode=disable
    dsn = "host=${google_sql_database_instance.netbird_db[0].public_ip_address} user=${google_sql_user.netbird[0].name} password=${google_sql_user.netbird[0].password} dbname=${google_sql_database.netbird[0].name} port=5432 sslmode=disable"
  }
}
