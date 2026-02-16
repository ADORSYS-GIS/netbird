# Provide examples for ALL three cloud providers
# User uncomments the one they're using

# AWS S3 Backend (recommended for AWS deployments)
# terraform {
#   backend "s3" {
#     bucket         = "netbird-tfstate-prod"
#     key            = "netbird-infrastructure/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "netbird-terraform-locks"
#     
#     # State versioning for recovery
#     versioning = true
#   }
# }

# GCP GCS Backend (recommended for GCP deployments)
# terraform {
#   backend "gcs" {
#     bucket  = "netbird-tfstate-prod"
#     prefix  = "netbird-infrastructure"
#   }
# }

# Azure Blob Backend (recommended for Azure deployments)
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "netbird-terraform-rg"
#     storage_account_name = "netbirdtfstate"
#     container_name       = "tfstate"
#     key                  = "netbird-infrastructure.tfstate"
#   }
# }
