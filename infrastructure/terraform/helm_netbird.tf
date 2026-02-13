# =============================================================================
# NetBird Helm Release Configuration
# Chart: https://artifacthub.io/packages/helm/netbird/netbird
# Version: 1.9.0
# =============================================================================

# Namespace for NetBird
resource "kubernetes_namespace" "netbird" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "netbird"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# =============================================================================
# Infrastructure Components (Optional)
# =============================================================================

# Optional Cert Manager
resource "helm_release" "cert_manager" {
  count            = var.install_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = var.cert_manager_namespace
  create_namespace = true
  version          = "v1.14.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = var.cert_manager_namespace
  }
}

# Optional Ingress Nginx
resource "helm_release" "ingress_nginx" {
  count            = var.install_ingress_nginx ? 1 : 0
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = var.ingress_nginx_namespace
  create_namespace = true
  version          = "4.9.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Enable HTTP/2 for gRPC support (required by NetBird signal and management gRPC)
  set {
    name  = "controller.config.use-http2"
    value = "true"
  }
}

# Optional ClusterIssuer for Let's Encrypt
resource "kubectl_manifest" "letsencrypt_issuer" {
  count = var.create_cert_issuer ? 1 : 0
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${var.cert_issuer_name}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: ${var.cert_issuer_name}-account-key
    solvers:
    - http01:
        ingress:
          class: ${var.ingress_class_name}
YAML

  depends_on = [helm_release.cert_manager]
}

# =============================================================================
# NetBird Official Helm Release
# =============================================================================

resource "helm_release" "netbird" {
  name       = "netbird"
  repository = "https://netbirdio.github.io/helms"
  chart      = "netbird"
  namespace  = kubernetes_namespace.netbird.metadata[0].name
  version    = var.netbird_chart_version

  timeout         = 600
  atomic          = false
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true

  values = [
    templatefile("${path.module}/values-official.yaml", {
      namespace             = var.namespace
      replica_count         = var.replica_count
      netbird_domain        = var.netbird_domain
      keycloak_url          = var.keycloak_url
      keycloak_realm        = var.keycloak_realm
      backend_client_id     = var.keycloak_mgmt_client_id
      dashboard_client_id   = var.keycloak_client_id
      db_engine             = var.use_external_db ? "postgres" : "sqlite"
      ingress_class_name    = var.ingress_class_name
      cert_issuer_name      = var.cert_issuer_name
      log_level             = var.log_level
      enable_metrics        = var.enable_metrics
      enable_relay          = var.enable_relay
      stun_servers          = jsonencode(var.stun_servers)
    })
  ]

  depends_on = [
    keycloak_openid_client.netbird_backend,
    keycloak_openid_client.netbird_dashboard,
    keycloak_openid_client_default_scopes.backend_scopes,
    keycloak_openid_client_default_scopes.dashboard_scopes,
    keycloak_openid_audience_protocol_mapper.dashboard_audience,
    kubectl_manifest.letsencrypt_issuer,
    kubernetes_secret.netbird_secrets
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "netbird_management_url" {
  description = "NetBird Management API URL"
  value       = "https://${var.netbird_domain}/api"
}

output "netbird_dashboard_url" {
  description = "NetBird Dashboard URL"
  value       = "https://${var.netbird_domain}"
}

output "netbird_grpc_url" {
  description = "NetBird gRPC URL for clients"
  value       = "https://${var.netbird_domain}:443"
}
