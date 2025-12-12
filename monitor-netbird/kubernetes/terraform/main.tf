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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
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

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# Data sources
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.cluster_location
}

# GCS Buckets
locals {
  buckets = [
    "loki-chunks",
    "loki-ruler",
    "loki-admin",
    "mimir-blocks",
    "mimir-ruler",
    "mimir-alertmanager",
    "tempo-traces",
  ]

  bucket_prefix         = var.project_id
  loki_schema_from_date = var.loki_schema_from_date
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
    environment = var.environment
    managed-by  = "terraform"
    component   = "observability"
  }
}

# GCP Service Account
resource "google_service_account" "observability_sa" {
  account_id   = var.gcp_service_account_name
  display_name = "GKE Observability Service Account"
  description  = "Service account for Loki, Tempo, Grafana, Mimir, and Prometheus in GKE"
}

# Grant Storage Object Admin role on all buckets
resource "google_storage_bucket_iam_member" "bucket_object_admin" {
  for_each = toset(local.buckets)

  bucket = google_storage_bucket.observability_buckets[each.key].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.observability_sa.email}"
}

# Grant Legacy Bucket Writer role on all buckets
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

# Cert-Manager ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName = "nginx"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [kubernetes_namespace.observability]
}

# Add Helm Repositories
resource "helm_release" "cert_manager" {
  count = var.install_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  wait = true
}

resource "helm_release" "nginx_ingress" {
  count = var.install_nginx_ingress ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = var.nginx_ingress_version

  wait = true
}

# Loki
resource "helm_release" "loki" {
  name       = "monitoring-stack-loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.loki_version

  values = [
    templatefile("../configs/monitoring-services/loki-values.yaml", {
      gcp_service_account_email = google_service_account.observability_sa.email
      k8s_service_account_name  = kubernetes_service_account.observability_sa.metadata[0].name
      loki_chunks_bucket        = google_storage_bucket.observability_buckets["loki-chunks"].name
      loki_ruler_bucket         = google_storage_bucket.observability_buckets["loki-ruler"].name
      loki_admin_bucket         = google_storage_bucket.observability_buckets["loki-admin"].name
      loki_schema_from_date     = local.loki_schema_from_date
      monitoring_domain         = var.monitoring_domain
    })
  ]

  depends_on = [
    kubernetes_service_account.observability_sa,
    google_service_account_iam_member.workload_identity_binding,
    google_storage_bucket_iam_member.bucket_object_admin
  ]
}

# Mimir
resource "helm_release" "mimir" {
  name       = "monitoring-stack-mimir"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "mimir-distributed"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.mimir_version

  values = [
    templatefile("../configs/monitoring-services/mimir-values.yaml", {
      gcp_service_account_email = google_service_account.observability_sa.email
      k8s_service_account_name  = kubernetes_service_account.observability_sa.metadata[0].name
      mimir_blocks_bucket       = google_storage_bucket.observability_buckets["mimir-blocks"].name
      mimir_ruler_bucket        = google_storage_bucket.observability_buckets["mimir-ruler"].name
      mimir_alertmanager_bucket = google_storage_bucket.observability_buckets["mimir-alertmanager"].name
      monitoring_domain         = var.monitoring_domain
    })
  ]

  depends_on = [
    kubernetes_service_account.observability_sa,
    google_service_account_iam_member.workload_identity_binding,
    google_storage_bucket_iam_member.bucket_object_admin
  ]
}

# Tempo
resource "helm_release" "tempo" {
  name       = "monitoring-stack-tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo-distributed"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.tempo_version

  values = [
    templatefile("../configs/monitoring-services/tempo-values.yaml", {
      gcp_service_account_email = google_service_account.observability_sa.email
      k8s_service_account_name  = kubernetes_service_account.observability_sa.metadata[0].name
      tempo_traces_bucket       = google_storage_bucket.observability_buckets["tempo-traces"].name
    })
  ]

  depends_on = [
    kubernetes_service_account.observability_sa,
    google_service_account_iam_member.workload_identity_binding,
    google_storage_bucket_iam_member.bucket_object_admin
  ]
}

# Prometheus
resource "helm_release" "prometheus" {
  name       = "monitoring-stack-prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.prometheus_version

  values = [
    templatefile("../configs/monitoring-services/prometheus-values.yaml", {
      gcp_service_account_email = google_service_account.observability_sa.email
      k8s_service_account_name  = kubernetes_service_account.observability_sa.metadata[0].name
      monitoring_domain         = var.monitoring_domain
      cluster_name              = var.cluster_name
      environment               = var.environment
    })
  ]

  depends_on = [
    helm_release.mimir,
    helm_release.loki
  ]
}

# Grafana
resource "helm_release" "grafana" {
  name       = "monitoring-stack-grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.grafana_version

  values = [
    templatefile("../configs/monitoring-services/grafana-values.yaml", {
      gcp_service_account_email = google_service_account.observability_sa.email
      k8s_service_account_name  = kubernetes_service_account.observability_sa.metadata[0].name
      monitoring_domain         = var.monitoring_domain
      grafana_admin_password    = var.grafana_admin_password
    })
  ]

  depends_on = [
    helm_release.prometheus,
    helm_release.loki,
    helm_release.mimir,
    helm_release.tempo
  ]
}

# Monitoring Ingress
resource "kubernetes_ingress_v1" "monitoring_stack" {
  metadata {
    name      = "monitoring-stack-ingress"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"          = "true"
      "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTP"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "300"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "300"
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "50m"
    }
  }

  spec {
    tls {
      hosts = [
        "grafana.${var.monitoring_domain}",
        "loki.${var.monitoring_domain}",
        "mimir.${var.monitoring_domain}",
        "tempo.${var.monitoring_domain}",
        "tempo-push.${var.monitoring_domain}",
        "prometheus.${var.monitoring_domain}"
      ]
      secret_name = "monitoring-tls"
    }

    # Grafana
    rule {
      host = "grafana.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Loki
    rule {
      host = "loki.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-loki-gateway"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Mimir
    rule {
      host = "mimir.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-mimir-nginx"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Tempo Query
    rule {
      host = "tempo.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-tempo-query-frontend"
              port {
                number = 3200
              }
            }
          }
        }
      }
    }

    # Tempo Push
    rule {
      host = "tempo-push.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-tempo-distributor"
              port {
                number = 4318
              }
            }
          }
        }
      }
    }

    # Prometheus
    rule {
      host = "prometheus.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-prometheus-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.grafana,
    kubernetes_manifest.letsencrypt_cluster_issuer
  ]
}

# Tempo gRPC Ingress
resource "kubernetes_ingress_v1" "tempo_grpc" {
  metadata {
    name      = "monitoring-stack-ingress-grpc"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                  = "nginx"
      "cert-manager.io/cluster-issuer"               = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "GRPC"
    }
  }

  spec {
    tls {
      hosts = [
        "tempo-grpc.${var.monitoring_domain}"
      ]
      secret_name = "monitoring-grpc-tls"
    }

    rule {
      host = "tempo-grpc.${var.monitoring_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-tempo-distributor"
              port {
                number = 4317
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.tempo,
    kubernetes_manifest.letsencrypt_cluster_issuer
  ]
}
