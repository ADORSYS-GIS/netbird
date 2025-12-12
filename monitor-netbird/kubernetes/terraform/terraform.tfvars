# GCP Configuration
project_id       = "your-gcp-project-id"
region           = "us-central1"
cluster_name     = "your-gke-cluster-name"
cluster_location = "us-central1-a"

# Kubernetes Configuration
namespace                = "observability"
k8s_service_account_name = "observability-sa"
gcp_service_account_name = "gke-observability-sa"

# Environment
environment = "production"

# Domain Configuration
monitoring_domain = "monitoring.yourdomain.com"
letsencrypt_email = "your-email@example.com"

# Grafana
grafana_admin_password = "your-secure-password-here"

# Helm Chart Versions (optional - defaults will be used if not specified)
# loki_version       = "6.16.0"
# mimir_version      = "5.5.0"
# tempo_version      = "1.10.1"
# prometheus_version = "25.27.0"
# grafana_version    = "8.5.2"

# Optional Components (set to true if you want Terraform to install these)
install_cert_manager  = false
install_nginx_ingress = false

# Loki Schema From Date
loki_schema_from_date = "2025-12-12"