# GKE Observability Infrastructure

Terraform configuration for provisioning GCP resources required by the observability stack on GKE.

## Overview

Creates GCS buckets, IAM configuration, and Workload Identity setup for Loki, Mimir, and Tempo on GKE with keyless authentication.

### Resources Created

**Storage Buckets:**
- `<PROJECT_ID>-loki-chunks`: Log chunk storage
- `<PROJECT_ID>-loki-ruler`: Loki ruler data
- `<PROJECT_ID>-mimir-blocks`: Long-term metrics
- `<PROJECT_ID>-tempo-traces`: Distributed traces

**IAM:**
- Service Account: `gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com`
- Bucket permissions: `storage.objectAdmin` and `storage.legacyBucketWriter`
- Workload Identity binding

**Kubernetes:**
- Namespace: `observability`
- Service Account: `observability-sa` (Workload Identity enabled)

## Prerequisites

### Tools
- Terraform 1.0+
- gcloud CLI
- kubectl

### GCP Setup

```bash
# Authenticate
gcloud auth application-default login

# Enable APIs
gcloud services enable storage.googleapis.com iam.googleapis.com container.googleapis.com

# Get cluster credentials
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region=<REGION> \
  --project=<PROJECT_ID>
```

## Configuration

Create `terraform.tfvars`:

```hcl
project_id                = "your-project-id"
region                    = "europe-west3"
cluster_name              = "your-cluster-name"
cluster_location          = "europe-west3"
namespace                 = "observability"
k8s_service_account_name  = "observability-sa"
gcp_service_account_name  = "gke-observability-sa"
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID | `my-project` |
| `region` | GCP region | `europe-west3` |
| `cluster_name` | GKE cluster name | `prod-cluster` |
| `cluster_location` | Cluster region/zone | `europe-west3` |
| `namespace` | Kubernetes namespace | `observability` |
| `k8s_service_account_name` | K8s service account | `observability-sa` |
| `gcp_service_account_name` | GCP service account | `gke-observability-sa` |

## Deployment

```bash
cd monitor-netbird/kubernetes/terraform

# Initialize
terraform init

# Preview changes
terraform plan

# Apply
terraform apply
```

### Verify Deployment

**Check GCS buckets:**
```bash
gcloud storage buckets list --filter="name:<PROJECT_ID>"
```

**Check service account:**
```bash
gcloud iam service-accounts list \
  --filter="email:gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com"
```

**Check Kubernetes resources:**
```bash
kubectl get namespace observability
kubectl get serviceaccount -n observability observability-sa
kubectl describe serviceaccount -n observability observability-sa
```

**Verify Workload Identity annotation:**
```bash
kubectl get serviceaccount observability-sa -n observability -o yaml | grep iam.gke.io
```

Expected:
```yaml
iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

### Test Workload Identity

```bash
kubectl run -it --rm test-workload-identity \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- gcloud storage buckets list --filter="name:<PROJECT_ID>-"
```

Should list the created buckets if authentication is working.

## Helm Integration

After applying Terraform, update your Helm values files:

**Loki** (`loki-values.yaml`):
```yaml
loki:
  storage:
    bucketNames:
      chunks: <PROJECT_ID>-loki-chunks
      ruler: <PROJECT_ID>-loki-ruler
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

**Mimir** (`mimir-values.yaml`):
```yaml
mimir:
  storage:
    bucketName: <PROJECT_ID>-mimir-blocks
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

**Tempo** (`tempo-values.yaml`):
```yaml
tempo:
  storage:
    bucketName: <PROJECT_ID>-tempo-traces
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

Proceed to the [Kubernetes Monitoring Guide](../../../docs/Monitoring-NetBird-Observability-Kubernetes.md).

## Outputs

```bash
terraform output
```

Example:
```hcl
gcp_service_account_email = "gke-observability-sa@my-project.iam.gserviceaccount.com"
gcs_bucket_names = {
  "loki-chunks" = "my-project-loki-chunks"
  "loki-ruler" = "my-project-loki-ruler"
  "mimir-blocks" = "my-project-mimir-blocks"
  "tempo-traces" = "my-project-tempo-traces"
}
k8s_namespace = "observability"
k8s_service_account = "observability-sa"
```

## Cleanup

```bash
terraform destroy
```

Warning: This deletes all buckets and their contents. Back up data first.

## Troubleshooting

### Permission Denied on GCS

**Check IAM policy:**
```bash
gcloud iam service-accounts get-iam-policy \
  gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

Expected binding:
```yaml
- members:
  - serviceAccount:<PROJECT_ID>.svc.id.goog[observability/observability-sa]
  role: roles/iam.workloadIdentityUser
```

**Check bucket IAM:**
```bash
gcloud storage buckets get-iam-policy gs://<PROJECT_ID>-loki-chunks
```

### Kubernetes Provider Authentication

Ensure kubectl is configured:
```bash
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region=<REGION> \
  --project=<PROJECT_ID>

kubectl cluster-info
```

### Bucket Already Exists

Import existing bucket:
```bash
terraform import 'google_storage_bucket.observability_buckets["loki-chunks"]' \
  <PROJECT_ID>-loki-chunks
```

### Workload Identity Not Working

**Checklist:**
1. Verify Workload Identity enabled on cluster
2. Check cluster has correct Workload Identity pool
3. Confirm service account annotation is correct
4. Ensure IAM binding has correct namespace and service account

**Debug:**
```bash
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- bash

# Inside pod
gcloud auth list
gcloud config list
```

## Security Notes

- Buckets use versioning for data protection
- Uniform bucket-level access enforces consistent permissions
- Lifecycle policies clean up old data after 90 days
- Workload Identity eliminates service account keys
- IAM follows least privilege principle

## Next Steps

1. Update Helm values files with bucket names from `terraform output`
2. Deploy cert-manager if using TLS
3. Follow [Kubernetes Monitoring Guide](../../../docs/Monitoring-NetBird-Observability-Kubernetes.md)
4. Configure monitoring for the observability stack itself