# Namespace for NetBird
resource "kubernetes_namespace" "netbird" {
  metadata {
    name = var.namespace
  }
}

# --- Infrastructure Components (Optional) ---

# Optional Cert Manager
resource "helm_release" "cert_manager" {
  count      = var.install_cert_manager ? 1 : 0
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true
  version    = "v1.12.0"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Optional Ingress Nginx
resource "helm_release" "ingress_nginx" {
  count      = var.install_ingress_nginx ? 1 : 0
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
}

# Optional ClusterIssuer for Let's Encrypt
resource "kubectl_manifest" "letsencrypt_issuer" {
  count = var.install_cert_manager ? 1 : 0
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
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: ${var.ingress_class_name}
YAML

  depends_on = [helm_release.cert_manager]
}

# --- NetBird Official Helm Release ---

resource "helm_release" "netbird" {
  name       = "netbird"
  repository = "https://netbirdio.github.io/helms"
  chart      = "netbird"
  namespace  = kubernetes_namespace.netbird.metadata[0].name
  version    = "1.9.0"

  values = [
    templatefile("${path.module}/values-official.yaml", {
      namespace           = var.namespace
      replica_count       = var.replica_count
      netbird_domain      = var.netbird_domain
      keycloak_url        = var.keycloak_url
      keycloak_realm      = var.keycloak_realm
      mgmt_client_id      = var.keycloak_mgmt_client_id
      mgmt_client_secret  = keycloak_openid_client.netbird_management.client_secret
      dashboard_client_id = var.keycloak_client_id
      db_engine           = var.use_external_db ? "postgres" : "sqlite"
      db_dsn              = var.use_external_db ? "host=${google_sql_database_instance.netbird_db[0].public_ip_address} user=${google_sql_user.netbird[0].name} password=${google_sql_user.netbird[0].password} dbname=${google_sql_database.netbird[0].name} port=5432 sslmode=disable" : ""
      ingress_class_name  = var.ingress_class_name
      cert_issuer_name    = var.cert_issuer_name
      encryption_key      = var.management_database_encryption_key
    })
  ]

  depends_on = [
    keycloak_openid_client.netbird_management,
    keycloak_openid_client.netbird_dashboard,
    google_sql_database_instance.netbird_db,
    kubectl_manifest.letsencrypt_issuer
  ]
}
