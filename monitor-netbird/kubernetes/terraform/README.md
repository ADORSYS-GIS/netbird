# GKE Observability Infrastructure Setup

Terraform configuration for provisioning GCP resources required by the NetBird observability stack on GKE.

## Overview

This configuration creates the complete infrastructure foundation for running Loki, Mimir, and Tempo on GKE with Google Cloud Storage backends. It handles GCS bucket provisioning, IAM configuration, and Workload Identity setup for secure, keyless authentication.

### Resources Created

**Google Cloud Storage Buckets**
- `<PROJECT_ID>-loki-chunks`: Loki log chunk storage
- `<PROJECT_ID>-loki-ruler`: Loki ruler data
- `<PROJECT_ID>-mimir-blocks`: Mimir long-term metrics
- `<PROJECT_ID>-tempo-traces`: Tempo distributed traces

All buckets include versioning, uniform bucket-level access, and 90-day lifecycle policies.

**IAM Configuration**
- GCP Service Account: `gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com`
- Bucket permissions: `roles/storage.objectAdmin` and `roles/storage.legacyBucketWriter`
- Workload Identity binding to Kubernetes Service Account

**Kubernetes Resources**
- Namespace: `observability`
- Service Account: `observability-sa` (annotated for Workload Identity)

## Prerequisites

### Required Tools
- Terraform 1.0+
- gcloud CLI
- kubectl

### GCP Setup

1. Authenticate with GCP:
   ```bash
   gcloud auth application-default login
   ```

2. Enable required APIs:
   ```bash
   gcloud services enable storage.googleapis.com \
     iam.googleapis.com \
     container.googleapis.com
   ```

3. Get GKE credentials:
   ```bash
   gcloud container clusters get-credentials <GKE_CLUSTER_NAME> \
     --region=<GCP_REGION> \
     --project=<PROJECT_ID>
   ```

## Configuration

### Variable Configuration

Edit `terraform.tfvars` with your environment values:

```hcl
project_id                = "your-gcp-project-id"
region                    = "europe-west3"
cluster_name              = "your-gke-cluster-name"
cluster_location          = "europe-west3"
namespace                 = "observability"
k8s_service_account_name  = "observability-sa"
gcp_service_account_name  = "gke-observability-sa"
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID | `my-netbird-project` |
| `region` | GCP region for resources | `europe-west3` |
| `cluster_name` | GKE cluster name | `netbird-prod` |
| `cluster_location` | GKE cluster zone/region | `europe-west3` |
| `namespace` | Kubernetes namespace | `observability` |
| `k8s_service_account_name` | K8s service account | `observability-sa` |
| `gcp_service_account_name` | GCP service account | `gke-observability-sa` |

## Deployment

### Initialize Terraform
```bash
cd monitor-netbird/kubernetes/terraform
terraform init
```

### Preview Changes
```bash
terraform plan
```

Review the planned resources carefully before applying.

### Apply Configuration
```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### Verify Deployment

**GCS Buckets**
```bash
gcloud storage buckets list --filter="name:<PROJECT_ID>"
```

**GCP Service Account**
```bash
gcloud iam service-accounts list \
  --filter="email:gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com"
```

**Kubernetes Resources**
```bash
kubectl get namespace observability
kubectl get serviceaccount -n observability observability-sa
kubectl describe serviceaccount -n observability observability-sa
```

**Workload Identity Annotation**
```bash
kubectl get serviceaccount observability-sa -n observability -o yaml | \
  grep iam.gke.io
```

Expected output:
```yaml
iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

## Workload Identity Test

Verify that pods can access GCS using Workload Identity:

```bash
kubectl run -it --rm test-workload-identity \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- gcloud storage buckets list --filter="name:<PROJECT_ID>-"
```

If successful, this command lists the created GCS buckets, confirming proper authentication.

## Integration with Helm

After applying this Terraform configuration, update your Helm values files with the created resource names:

### Loki Configuration
Edit `monitor-netbird/kubernetes/configs/monitoring-services/loki-values.yaml`:
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

### Mimir Configuration
Edit `monitor-netbird/kubernetes/configs/monitoring-services/mimir-values.yaml`:
```yaml
mimir:
  storage:
    bucketName: <PROJECT_ID>-mimir-blocks
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

### Tempo Configuration
Edit `monitor-netbird/kubernetes/configs/monitoring-services/tempo-values.yaml`:
```yaml
tempo:
  storage:
    bucketName: <PROJECT_ID>-tempo-traces
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

Proceed to the [Kubernetes Monitoring Guide](../../../docs/Monitoring-NetBird-Observability-Kubernetes.md) to deploy the observability stack.

## Terraform Outputs

After successful deployment, Terraform outputs key values for Helm configuration:

```bash
terraform output
```

Example output:
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

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This deletes all GCS buckets and their contents. Ensure you have backups before proceeding.

## Troubleshooting

### Permission Denied on GCS Access

**Symptoms**: Pods receive "Permission denied" when accessing GCS buckets.

**Solution**: Verify Workload Identity binding and IAM policies.

1. Check GCP Service Account IAM policy:
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

2. Verify bucket IAM policies:
   ```bash
   gcloud storage buckets get-iam-policy gs://<PROJECT_ID>-loki-chunks
   ```

### Kubernetes Provider Authentication Fails

**Symptoms**: Terraform fails to authenticate with GKE cluster.

**Solution**: Ensure kubectl context is configured:
```bash
gcloud container clusters get-credentials <GKE_CLUSTER_NAME> \
  --region=<GCP_REGION> \
  --project=<PROJECT_ID>
```

Verify connection:
```bash
kubectl cluster-info
```

### GCS Bucket Already Exists

**Symptoms**: Terraform reports bucket already exists.

**Solution**: Import existing bucket into Terraform state:
```bash
terraform import 'google_storage_bucket.observability_buckets["loki-chunks"]' \
  <PROJECT_ID>-loki-chunks
```

Repeat for other buckets as needed.

### Workload Identity Not Working

**Symptoms**: Pods cannot authenticate to GCP despite correct annotations.

**Checklist**:
1. Verify Workload Identity is enabled on the GKE cluster
2. Check that the GKE cluster has the correct Workload Identity pool
3. Confirm the service account annotation is correct
4. Ensure the IAM binding includes the correct namespace and service account name

Test with debug pod:
```bash
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- bash

# Inside the pod
gcloud auth list
gcloud config list
```

## Security Notes

- All buckets use versioning for data protection
- Uniform bucket-level access enforces consistent permissions
- Lifecycle policies automatically clean up old data
- Workload Identity eliminates need for service account keys
- IAM follows principle of least privilege

## Next Steps

1. Review and customize Helm values files with bucket names
2. Deploy cert-manager and Ingress controller if using TLS
3. Follow the [Kubernetes Monitoring Guide](../../../docs/Monitoring-NetBird-Observability-Kubernetes.md)
4. Configure monitoring and alerting for the observability stack itself