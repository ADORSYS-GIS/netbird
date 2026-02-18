# Managed PostgreSQL Instances across cloud providers

# ---------------------------------------------------------------------------
# AWS RDS
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "netbird" {
  count       = var.cloud_provider == "aws" ? 1 : 0
  name_prefix = "netbird-db-"
  subnet_ids  = var.subnet_ids
  tags        = var.tags
}

resource "aws_db_instance" "netbird" {
  count = var.cloud_provider == "aws" ? 1 : 0

  identifier_prefix = "netbird-"
  engine            = "postgres"
  engine_version    = "16.1"

  instance_class    = var.instance_class
  allocated_storage = var.storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.database_name
  username = var.username
  password = var.password

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days

  db_subnet_group_name   = aws_db_subnet_group.netbird[0].name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot    = true # For demo/simplicity, strictly in prod set to false

  tags = var.tags
}

# ---------------------------------------------------------------------------
# GCP Cloud SQL
# ---------------------------------------------------------------------------

resource "google_sql_database_instance" "netbird" {
  count            = var.cloud_provider == "gcp" ? 1 : 0
  name             = "netbird-${lookup(var.tags, "Environment", "prod")}"
  database_version = "POSTGRES_16"
  region           = lookup(var.tags, "Region", "us-central1")

  settings {
    tier              = var.instance_class
    availability_type = var.multi_az ? "REGIONAL" : "ZONAL"
    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }
    ip_configuration {
      ipv4_enabled    = true
      private_network = var.vpc_id
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Flexible Server
# ---------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "netbird" {
  count               = var.cloud_provider == "azure" ? 1 : 0
  name                = "netbird-${lookup(var.tags, "Environment", "prod")}"
  resource_group_name = lookup(var.tags, "ResourceGroup", "netbird-rg")
  location            = lookup(var.tags, "Location", "East US")
  version             = "16"

  delegated_subnet_id = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : null
  private_dns_zone_id = lookup(var.tags, "DNSZoneId", null)

  administrator_login    = var.username
  administrator_password = var.password

  storage_mb = var.storage_gb * 1024

  sku_name   = var.instance_class
  
  high_availability {
    mode = var.multi_az ? "ZoneRedundant" : "Disabled"
  }
}
