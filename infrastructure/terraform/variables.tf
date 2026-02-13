variable "create_cert_issuer" {
  description = "Whether to create the ClusterIssuer"
  type        = bool
  default     = true
}

variable "cert_manager_namespace" {
  description = "Namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "ingress_nginx_namespace" {
  description = "Namespace for ingress-nginx"
  type        = string
  default     = "ingress-nginx"
}

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
  description = "Base domain for NetBird services (e.g., netbird.example.com)"
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
  default     = "netbird-backend"
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
  default     = ""
}

variable "replica_count" {
  description = "Number of replicas for HA components"
  type        = number
  default     = 1
}

variable "db_instance_tier" {
  description = "Tier for Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "management_database_encryption_key" {
  description = "Encryption key for the NetBird management database (32 chars, auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "netbird_chart_version" {
  description = "Version of the NetBird Helm chart"
  type        = string
  default     = "1.9.0"
}

variable "netbird_admin_email" {
  description = "Email for the initial NetBird admin user"
  type        = string
  default     = ""
}

variable "netbird_admin_password" {
  description = "Password for the initial NetBird admin user (temporary, should be changed)"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Log level for NetBird components (debug, info, warn, error)"
  type        = string
  default     = "info"
}

variable "turn_secret" {
  description = "Shared secret for TURN server authentication (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stun_servers" {
  description = "List of STUN server URIs"
  type        = list(string)
  default     = ["stun:stun.l.google.com:19302"]
}

variable "enable_relay" {
  description = "Enable NetBird relay service"
  type        = bool
  default     = true
}
