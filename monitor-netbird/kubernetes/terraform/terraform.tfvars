# GCP Configuration
project_id       = "<PROJECT_ID>"
region           = "<REGION>"
cluster_name     = "<CLUSTER_NAME>"
cluster_location = "<REGION>"

# Kubernetes Configuration
namespace                = "<NAMESPACE>"
k8s_service_account_name = "<K8S_SERVICE_ACCOUNT_NAME>"
gcp_service_account_name = "<GCP_SERVICE_ACCOUNT_NAME>"

# Environment
environment = "<ENVIRONMENT>"

# Domain Configuration
monitoring_domain = "<MONITORING_DOMAIN>"
letsencrypt_email = "<LETS_ENCRYPT_EMAIL>"

# Grafana
grafana_admin_password = "<GRAFANA_ADMIN_PASSWORD>"

# Helm Chart Versions (optional - defaults will be used if not specified)
loki_version       = "6.20.0"
mimir_version      = "5.5.0"
tempo_version      = "1.57.0"
prometheus_version = "25.27.0"
grafana_version    = "10.3.0"

# Optional Components (set to true if you want Terraform to install these)
install_cert_manager  = false
ingress_class_name    = "nginx"            # Set to your cluster's ingress class (e.g., "nginx", "traefik")
cert_issuer_name      = "letsencrypt-prod" # Set to your Cert-Manager Issuer name
install_nginx_ingress = false

# Loki Schema From Date
loki_schema_from_date = "2025-12-13"
