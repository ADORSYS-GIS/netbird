terraform {
  required_version = ">= 1.6.0"

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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# provider "google" {
#   project = var.gcp_project
#   region  = var.gcp_region
# }

# provider "azurerm" {
#   features {}
#   subscription_id = var.azure_subscription_id
# }

provider "keycloak" {
  # Keycloak requires an OIDC client even when using direct credentials.
  # 'admin-cli' is the standard, built-in client for administrative access.
  client_id     = "admin-cli"
  client_secret = var.keycloak_admin_client_secret
  username      = var.keycloak_admin_username
  password      = var.keycloak_admin_password
  url           = var.keycloak_url
}
