variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "cloud_provider" {
  description = "Cloud provider for the EKS/GKE/AKS cluster"
  type        = string
  default     = "aws"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "netbird-cluster"
}

variable "netbird_domain" {
  description = "NetBird domain"
  type        = string
}

variable "netbird_version" {
  description = "NetBird version"
  type        = string
  default     = "0.29.0"
}

variable "database_type" {
  description = "Database type (postgresql, mysql)"
  type        = string
  default     = "postgresql"
}

variable "database_mode" {
  description = "Database mode (create, existing)"
  type        = string
  default     = "create"
}

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "keycloak_realm" {
  description = "Keycloak realm"
  type        = string
  default     = "netbird"
}

variable "keycloak_client_id" {
  description = "Keycloak client ID"
  type        = string
  default     = "netbird-client"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "netbird"
}

variable "helm_chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.1.0"
}
