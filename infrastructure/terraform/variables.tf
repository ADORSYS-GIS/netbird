variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The GKE cluster name"
  type        = string
}

variable "netbird_domain" {
  description = "Base domain for NetBird services"
  type        = string
  default     = "example.com"
}

variable "keycloak_url" {
  description = "The external Keycloak URL (e.g., https://keycloak.example.com)"
  type        = string
}

variable "keycloak_admin_user" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_realm" {
  description = "The Keycloak realm name"
  type        = string
  default     = "netbird"
}

variable "keycloak_client_id" {
  description = "Keycloak Public Client ID for Dashboard"
  type        = string
  default     = "netbird-dashboard"
}

variable "keycloak_mgmt_client_id" {
  description = "Keycloak Confidential Client ID for Management service account"
  type        = string
  default     = "netbird-management"
}

variable "cert_issuer_name" {
  description = "Name of the existing ClusterIssuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "ingress_class_name" {
  description = "Existing Ingress class name"
  type        = string
  default     = "nginx"
}

variable "install_cert_manager" {
  description = "Whether to install cert-manager"
  type        = bool
  default     = false
}

variable "install_ingress_nginx" {
  description = "Whether to install ingress-nginx"
  type        = bool
  default     = false
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "use_external_db" {
  description = "Whether to use external Cloud SQL PostgreSQL database (set to false for SQLite)"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for NetBird resources"
  type        = string
  default     = "netbird"
}

variable "db_password" {
  description = "Password for the Cloud SQL PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "replica_count" {
  description = "Number of replicas for HA components"
  type        = number
  default     = 3
}

variable "db_instance_tier" {
  description = "Tier for Cloud SQL instance"
  type        = string
  default     = "db-f1-micro" # Use db-custom-2-7680 or similar for production
}

variable "management_database_encryption_key" {
  description = "Encryption key for the NetBird management database"
  type        = string
  sensitive   = true
}
