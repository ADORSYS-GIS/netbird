terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

variable "cloud_provider" {
  description = "Cloud provider to provision DB in (aws, gcp, azure)"
  type        = string
}

variable "environment" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "instance_class" {
  description = "DB Instance Class"
  type        = string
}

variable "storage_gb" {
  description = "Storage in GB"
  type        = number
}

variable "region" {
  description = "Region for AWS/GCP"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource Group for Azure"
  type        = string
  default     = ""
}

variable "location" {
  description = "Location for Azure"
  type        = string
  default     = ""
}

# AWS RDS
resource "aws_db_instance" "netbird" {
  count = var.cloud_provider == "aws" ? 1 : 0
  
  identifier           = "netbird-${var.environment}"
  engine               = "postgres"
  engine_version       = "16.1"
  instance_class       = var.instance_class
  allocated_storage    = var.storage_gb
  storage_encrypted    = true
  
  db_name  = "netbird"
  username = var.db_username
  password = var.db_password
  
  multi_az               = true
  publicly_accessible    = false # Secure by default
  skip_final_snapshot    = true  # For demo simplicity, set to false in prod
  
  # VPC/Subnet group would be needed here in real AWS setup. 
  # Assuming default VPC or user sets it up via other means for now.
}

# GCP Cloud SQL
resource "google_sql_database_instance" "netbird" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  
  name             = "netbird-${var.environment}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  database_version = "POSTGRES_15" # 16 might not be available in all regions yet in TF default
  region           = var.region
  
  settings {
    tier              = var.instance_class # e.g., db-f1-micro
    availability_type = "REGIONAL"
    disk_size         = var.storage_gb
    
    ip_configuration {
      ipv4_enabled    = true # Or false if using private IP
      # authorized_networks = ...
    }
  }
  
  deletion_protection = false # For demo simplicity
}

resource "google_sql_user" "users" {
  count    = var.cloud_provider == "gcp" ? 1 : 0
  name     = var.db_username
  instance = google_sql_database_instance.netbird[0].name
  password = var.db_password
}

# Azure Flexible Server
resource "azurerm_postgresql_flexible_server" "netbird" {
  count = var.cloud_provider == "azure" ? 1 : 0
  
  name                = "netbird-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "16"
  
  sku_name   = var.instance_class # e.g., B_Standard_B1ms
  storage_mb = var.storage_gb * 1024
  
  administrator_login    = var.db_username
  administrator_password = var.db_password
  
  high_availability {
    mode = "ZoneRedundant"
  }
  
  backup_retention_days = 7
}

output "dsn" {
  sensitive = true
  value = var.cloud_provider == "aws" ? (
    "host=${try(aws_db_instance.netbird[0].address, "")} port=5432 dbname=netbird user=${var.db_username} password=${var.db_password} sslmode=require"
  ) : var.cloud_provider == "gcp" ? (
    "host=${try(google_sql_database_instance.netbird[0].public_ip_address, "")} port=5432 dbname=netbird user=${var.db_username} password=${var.db_password} sslmode=require"
  ) : var.cloud_provider == "azure" ? (
    "host=${try(azurerm_postgresql_flexible_server.netbird[0].fqdn, "")} port=5432 dbname=netbird user=${var.db_username} password=${var.db_password} sslmode=require"
  ) : ""
}
