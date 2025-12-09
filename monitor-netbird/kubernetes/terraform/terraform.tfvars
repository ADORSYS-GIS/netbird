project_id               = "<PROJECT_ID>" # Replace with your GCP Project ID
region                   = "<GCP_REGION>"    # Replace with your desired GCP region (e.g., europe-west3)
cluster_name             = "<GKE_CLUSTER_NAME>" # Replace with your GKE Cluster Name
cluster_location         = "<GKE_CLUSTER_LOCATION>" # Replace with your GKE Cluster Location (e.g., europe-west3)
namespace                = "observability" # Kubernetes namespace for observability components
k8s_service_account_name = "observability-sa" # Kubernetes service account name
gcp_service_account_name = "gke-observability-sa" # GCP service account name