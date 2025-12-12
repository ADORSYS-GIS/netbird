# Observability Stack on Kubernetes

Deploy a production-ready observability stack (Prometheus, Loki, Mimir, Tempo, Grafana) on Kubernetes using Terraform.

## Overview

This guide uses Terraform to fully automate the deployment, including:
1.  **Infrastructure**: GCS buckets for long-term storage.
2.  **Identity**: GCP Service Accounts and Workload Identity bindings.
3.  **Application**: Helm charts for all monitoring components.
4.  **Access**: Ingress and TLS certificates (optional).

## Prerequisites

-   **Google Cloud Project**: With billing enabled.
-   **Kubernetes Cluster (GKE)**: Running and accessible via `kubectl`.
-   **Terraform**: Installed globally.
-   **gcloud CLI**: Authenticated with your project.

> [!NOTE]
> Ensure you are authenticated:
> `gcloud auth application-default login`

## Deployment

### 1. Configure Variables

Navigate to the Terraform directory:
```bash
cd monitor-netbird/kubernetes/terraform
```

Create or edit `terraform.tfvars`:

```hcl
project_id               = "your-project-id"
region                   = "us-central1"
cluster_name             = "your-cluster-name"
cluster_location         = "us-central1-a"
monitoring_domain        = "monitor.example.com"
letsencrypt_email        = "admin@example.com"
grafana_admin_password   = "secure-password"

# Optional: Enable Ingress
install_nginx_ingress    = true
install_cert_manager     = true
```

### 2. Apply Configuration

Run the following commands to provision everything:

```bash
terraform init
terraform apply
```

Review the plan and type `yes` to confirm.

> [!PLACEHOLDER]
> **Screenshot Required**: Capture the output of `terraform apply` showing the plan summary (e.g., "Plan: X to add, 0 to change...").
> *Description: Shows the resources Terraform will create, verifying the configuration.*

### 3. Verify Deployment

Once Terraform completes, verify the pods are running:

```bash
kubectl get pods -n observability
```

> [!PLACEHOLDER]
> **Screenshot Required**: Capture the output of `kubectl get pods -n observability` showing all pods in `Running` or `Completed` state.
> *Description: Confirms that all monitoring components (Loki, Mimir, Tempo, Prometheus, Grafana) are successfully deployed.*

### 4. Access Grafana

Navigate to your configured domain:
`https://grafana.monitor.example.com`

*   **User**: `admin`
*   **Password**: The value you set in `grafana_admin_password`.

> [!PLACEHOLDER]
> **Screenshot Required**: Capture the Grafana login screen or the main dashboard after logging in.
> *Description: Visual confirmation that the Grafana UI is accessible via the configured ingress.*

## Architecture

This setup deploys:
-   **Loki**: Logs (stores chunks in `${project_id}-loki-chunks`).
-   **Mimir**: Metrics (stores blocks in `${project_id}-mimir-blocks`).
-   **Tempo**: Traces (stores traces in `${project_id}-tempo-traces`).
-   **Prometheus**: Scrapes metrics and forwards them to Mimir.

## Maintenance

### Updating Values
To change configuration (e.g., retention periods), edit `variables.tf` or `terraform.tfvars` and run `terraform apply` again.

### Cleaning Up
To remove all resources (infrastructure and applications):
```bash
terraform destroy
```
