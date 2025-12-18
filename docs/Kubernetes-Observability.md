# Kubernetes Observability Stack

This document describes the architecture, deployment, and configuration of a production-grade observability stack on Google Kubernetes Engine (GKE). The stack integrates Loki, Grafana, Tempo, and Mimir (LGTM) with Prometheus to provide a complete monitoring solution for logs, metrics, and traces for any application or infrastructure.

## Overview

The observability stack is designed to be production-ready, scalable, and portable. It leverages:

-   **Loki**: For distributed logging.
-   **Mimir**: For long-term Prometheus metrics storage.
-   **Tempo**: For distributed tracing.
-   **Prometheus**: For metrics collection and scraping.
-   **Grafana**: For data visualization and dashboarding.
-   **Google Cloud Storage (GCS)**: For cost-effective, durable backend storage.

Infrastructure provisioning and application deployment are fully automated using Terraform and Helm.

## Architecture

The system uses a centralized ingress controller to route traffic to specific services. Workload Identity is configured to securely authenticate Kubernetes Service Accounts with Google Cloud APIs, eliminating the need for static service account keys.

```mermaid
graph TD
    User([User / External Traffic]) -->|HTTPS| LB[GCP LoadBalancer]
    LB -->|Routing| Ingress[Ingress Controller]
    
    subgraph "GKE Cluster (Namespace: observability)"
        Ingress -->|Host: grafana.*| Grafana[Grafana UI]
        Ingress -->|Host: loki.*| Loki[Loki Gateway]
        Ingress -->|Host: mimir.*| Mimir[Mimir Gateway]
        Ingress -->|Host: tempo.*| Tempo[Tempo Gateway]
        Ingress -->|Host: prometheus.*| Prom[Prometheus]
        
        Prom -->|Remote Write| Mimir
        Prom -->|Scrape| K8s[K8s Metrics]
    end
    
    subgraph "Google Cloud Platform"
        IAM[IAM & Workload Identity]
        GCS[(Google Cloud Storage)]
    end
    
    Loki -->|Read/Write| GCS
    Mimir -->|Read/Write| GCS
    Tempo -->|Read/Write| GCS
    
    K8sSA[K8s ServiceAccount] -.->|Impersonates| GCPSA[GCP ServiceAccount]
    GCPSA -->|IAM Roles| GCS
```

## Prerequisites

Before deploying the stack, ensure the following requirements are met:

1.  **Terraform**: Version 1.0 or later installed.
2.  **Google Cloud CLI**: Installed and authenticated with `gcloud auth login` and `gcloud auth application-default login`.
3.  **Kubernetes Access**: `kubectl` configured with context for the target GKE cluster.
4.  **Permissions**: The authenticated user must have permissions to create GCS buckets, Service Accounts, and assign IAM roles (Storage Object Admin).

## Configuration

The deployment is configured via Terraform variables. Create a `terraform.tfvars` file in `monitor-netbird/kubernetes/terraform/` to define your environment-specific values.

| Variable | Description | Required | Default |
| :--- | :--- | :---: | :--- |
| `project_id` | Google Cloud Project ID. | Yes | - |
| `cluster_name` | Name of the target GKE cluster. | Yes | - |
| `region` | GCP Region for resources (e.g., `europe-west3`). | No | `us-central1` |
| `monitoring_domain` | Base domain for endpoints (e.g., `obs.example.com`). | Yes | - |
| `ingress_class_name` | Ingress Class Name (e.g., `nginx`, `traefik`). | No | `nginx` |
| `cert_issuer_name` | Name of the Cert-Manager Issuer (e.g., `letsencrypt-prod`). | No | `letsencrypt-prod` |
| `grafana_admin_password` | Initial admin password for Grafana. | Yes | - |

### Ingress Compatibility

This module is agnostic to the Ingress Controller and Certificate Issuer. By default, it assumes `nginx` and `letsencrypt-prod`. To use a different configuration (e.g., Traefik or a custom ClusterIssuer), update the `ingress_class_name` and `cert_issuer_name` variables in `terraform.tfvars`.

## Installation

1.  **Initialize Terraform**
    
    Navigate to the Terraform directory and initialize the project to download required providers and modules.

    ```bash
    cd monitor-netbird/kubernetes/terraform
    terraform init
    ```

2.  **Plan Deployment**

    Generate an execution plan to verify the resources that will be created.

    ```bash
    terraform plan
    ```

3.  **Apply Configuration**

    Execute the plan to provision infrastructure and deploy the application stack.

    ```bash
    terraform apply
    ```

## Verification

### Service Status

Verify that all pods are running successfully in the `<NAMESPACE>` (default: `observability`) namespace.
 
```bash
kubectl get pods -n <NAMESPACE>
```

![Kubectl Get Pods](img/kubectl-get-pods.png)

### Public Endpoints

The stack exposes the following endpoints for data ingestion and visualization. Replace `<monitoring_domain>` with your configured domain (e.g., `stack.observe.camer.digital`).

| Service | Endpoint URL | Purpose | Method | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Grafana** | `https://grafana.<monitoring_domain>` | **Visualization** | GET | Main UI for dashboards and alerts. |
| **Loki** | `https://loki.<monitoring_domain>/loki/api/v1/push` | **Logs Ingestion** | POST | Send logs via HTTP (JSON/Snappy). |
| **Mimir** | `https://mimir.<monitoring_domain>/prometheus/api/v1/push` | **Metrics Ingestion** | POST | Send metrics via Prometheus Remote Write. |
| **Tempo** (HTTP) | `https://tempo-push.<monitoring_domain>/v1/traces` | **Traces Ingestion** | POST | Send traces via OTLP HTTP. |
| **Tempo** (gRPC) | `tempo-grpc.<monitoring_domain>:443` | **Traces Ingestion** | gRPC | Send traces via OTLP gRPC. |

### Manual Verification

You can verify the Write Path (Ingestion) by sending synthetic data to the exposed endpoints.

**Example Verification (Mimir Connectivity):**

```bash
curl -v -G "https://mimir.<monitoring_domain>/prometheus/api/v1/query" \
  --data-urlencode 'query=up'
```

**Example Verification (Loki Push):**

```bash
# Set timestamp to avoid shell quoting issues
TS=$(date +%s)000000000
curl -v -H "Content-Type: application/json" -XPOST \
  "https://loki.<monitoring_domain>/loki/api/v1/push" \
  --data-raw "{\"streams\": [{ \"stream\": { \"test\": \"manual_curl\" }, \"values\": [ [ \"$TS\", \"manual_test_log\" ] ] }]}"
```
### Useful API Documentation

For advanced usage, refer to the official API documentation:

*   **Loki**: [Push API (Protobuf/JSON)](https://grafana.com/docs/loki/latest/reference/api/#push-log-entries-to-loki)
*   **Mimir**: [Prometheus Remote Write API](https://grafana.com/docs/mimir/latest/references/http-api/#remote-write)
*   **Tempo**: [OTLP HTTP API](https://grafana.com/docs/tempo/latest/configuration/?pg=docs-tempo-latest-api-otlp-http#otlp)
### Dashboard Access

Access the Grafana dashboard using the domain configured in `monitoring_domain`.

-   **URL**: `https://grafana.<monitoring_domain>`
-   **Username**: `admin`
-   **Password**: *<grafana_admin_password>*

![Grafana Dashboard](img/grafana-dashboard.png)

## Maintenance

### Upgrades

To upgrade components, update the version variables in `terraform.tfvars` or `variables.tf` and re-run `terraform apply`.

**Note**: The current stack uses **Loki v6.20.0**. Major version upgrades should be tested in a staging environment first to ensure compatibility with the storage schema.

### Uninstallation

To remove all resources created by this module:

```bash
terraform destroy
```

**Warning**: Google Cloud Storage buckets containing observability data have `force_destroy` set to `false` to prevent accidental data loss. If you intend to delete the data, you must empty the buckets manually before running destroy.
