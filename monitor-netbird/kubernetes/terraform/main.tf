terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Data sources
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.cluster_location
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "observe-472521"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west3"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "observe-prod-cluster"
}

variable "cluster_location" {
  description = "GKE Cluster Location"
  type        = string
  default     = "europe-west3"
}

variable "namespace" {
  description = "Kubernetes namespace for observability"
  type        = string
  default     = "observability"
}

variable "k8s_service_account_name" {
  description = "Kubernetes service account name"
  type        = string
  default     = "observability-sa"
}

variable "gcp_service_account_name" {
  description = "GCP service account name"
  type        = string
  default     = "gke-observability-sa"
}

# GCS Buckets
locals {
  buckets = [
    "loki-chunks-observe472521",
    "loki-ruler-observe472521",
    "mimir-blocks-observe472521",
    "tempo-traces-observe472521"
  ]
  
  bucket_prefix = "${var.project_id}-observability"
}

resource "google_storage_bucket" "observability_buckets" {
  for_each = toset(local.buckets)
  
  name          = "${local.bucket_prefix}-${each.key}"
  location      = var.region
  force_destroy = false
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  labels = {
    environment = "production"
    managed-by  = "terraform"
    component   = "observability"
  }
}

# GCP Service Account
resource "google_service_account" "observability_sa" {
  account_id   = var.gcp_service_account_name
  display_name = "GKE Observability Service Account"
  description  = "Service account for Loki, Tempo, Grafana, and Prometheus in GKE"
}

# Grant Storage Object Admin role on all buckets
resource "google_storage_bucket_iam_member" "bucket_object_admin" {
  for_each = toset(local.buckets)
  
  bucket = google_storage_bucket.observability_buckets[each.key].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.observability_sa.email}"
}

# Grant Legacy Bucket Writer role on all buckets (for Loki compatibility)
resource "google_storage_bucket_iam_member" "bucket_legacy_writer" {
  for_each = toset(local.buckets)
  
  bucket = google_storage_bucket.observability_buckets[each.key].name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${google_service_account.observability_sa.email}"
}

# Kubernetes Namespace
resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
    
    labels = {
      name       = var.namespace
      managed-by = "terraform"
    }
  }
}

# Kubernetes Service Account
resource "kubernetes_service_account" "observability_sa" {
  metadata {
    name      = var.k8s_service_account_name
    namespace = kubernetes_namespace.observability.metadata[0].name
    
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.observability_sa.email
    }
    
    labels = {
      managed-by = "terraform"
    }
  }
}

# Workload Identity Binding
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.observability_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.k8s_service_account_name}]"
}

# Outputs
output "gcp_service_account_email" {
  description = "GCP Service Account Email"
  value       = google_service_account.observability_sa.email
}

output "kubernetes_service_account_name" {
  description = "Kubernetes Service Account Name"
  value       = kubernetes_service_account.observability_sa.metadata[0].name
}

output "namespace" {
  description = "Kubernetes Namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "bucket_names" {
  description = "GCS Bucket Names"
  value = {
    for key, bucket in google_storage_bucket.observability_buckets :
    key => bucket.name
  }
}

output "workload_identity_pool" {
  description = "Workload Identity Pool"
  value       = "${var.project_id}.svc.id.goog"
}

output "bucket_urls" {
  description = "GCS Bucket URLs for Helm values"
  value = {
    for key, bucket in google_storage_bucket.observability_buckets :
    key => "gs://${bucket.name}"
  }
}