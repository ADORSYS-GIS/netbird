variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
}

variable "cluster_location" {
  description = "GKE Cluster Location"
  type        = string
}

variable "namespace" {
  description = "Kubernetes Namespace for Observability Stack"
  type        = string
  default     = "observability"
}

variable "k8s_service_account_name" {
  description = "Kubernetes Service Account Name"
  type        = string
  default     = "observability-sa"
}

variable "gcp_service_account_name" {
  description = "GCP Service Account Name (6-30 chars, lowercase, start with letter, end with letter/number)"
  type        = string
  default     = "gke-observability-sa"

  validation {
    condition     = can(regex("^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$", var.gcp_service_account_name))
    error_message = "GCP service account name must be 6-30 characters, start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and end with a lowercase letter or number."
  }
}

variable "environment" {
  description = "Environment (e.g., restricted, production)"
  type        = string
  default     = "production"
}

variable "monitoring_domain" {
  description = "Domain for monitoring services"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt notifications"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "install_cert_manager" {
  description = "Whether to install cert-manager"
  type        = bool
  default     = false
}

variable "install_nginx_ingress" {
  description = "Whether to install NGINX Ingress Controller"
  type        = bool
  default     = false
}

variable "cert_manager_version" {
  description = "Version of cert-manager chart"
  type        = string
  default     = "v1.15.0"
}

variable "nginx_ingress_version" {
  description = "Version of ingress-nginx chart"
  type        = string
  default     = "4.10.1"
}

variable "loki_version" {
  description = "Version of Loki chart"
  type        = string
  default     = "6.6.4"
}

variable "mimir_version" {
  description = "Version of Mimir chart"
  type        = string
  default     = "5.5.0"
}

variable "tempo_version" {
  description = "Version of Tempo chart"
  type        = string
  default     = "1.57.0"
}

variable "prometheus_version" {
  description = "Version of Prometheus chart"
  type        = string
  default     = "25.27.0"
}

variable "grafana_version" {
  description = "Version of Grafana chart"
  type        = string
  default     = "10.3.0"
}

variable "loki_schema_from_date" {
  description = "Date from which Loki schema is effective (YYYY-MM-DD)"
  type        = string
  default     = "2024-01-01"
}
