# GCP Configuration
project_id       = "<YOUR_GCP_PROJECT_ID>"
region           = "<YOUR_GCP_REGION>"
cluster_name     = "<YOUR_CLUSTER_NAME>"
cluster_location = "<YOUR_CLUSTER_LOCATION>"

# Kubernetes Configuration
namespace                = "<YOUR_K8S_NAMESPACE>"
k8s_service_account_name = "<YOUR_K8S_SERVICE_ACCOUNT_NAME>"
gcp_service_account_name = "<YOUR_GCP_SERVICE_ACCOUNT_NAME>"

# Environment
environment = "<YOUR_ENVIRONMENT>"

# Domain Configuration
monitoring_domain = "<YOUR_DOMAIN>"
letsencrypt_email = "<YOUR_EMAIL>"

# Grafana
grafana_admin_password = "<YOUR_SECURE_PASSWORD>"

# Helm Chart Versions (optional - defaults will be used if not specified)
loki_version = "6.16.0"
# mimir_version      = "5.5.0"
# tempo_version      = "1.10.1"
# prometheus_version = "25.27.0"
# grafana_version    = "8.5.2"

# Optional Components (set to true if you want Terraform to install these)
install_cert_manager  = false
install_nginx_ingress = true

# Loki Schema From Date
loki_schema_from_date = "2025-12-13"
