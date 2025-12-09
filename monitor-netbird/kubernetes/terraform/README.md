# GKE Observability Infrastructure Setup

This Terraform configuration creates the necessary GCP and Kubernetes resources for your observability stack.

## What This Creates

### GCS Buckets (4)
- `observe-472521-observability-loki-chunks` - Loki log chunks storage
- `observe-472521-observability-loki-ruler` - Loki ruler storage
- `observe-472521-observability-loki-admin` - Loki admin storage
- `observe-472521-observability-tempo-data` - Tempo traces storage

### GCP Service Account
- Name: `gke-observability-sa@observe-472521.iam.gserviceaccount.com`
- Roles on all buckets:
  - `roles/storage.objectAdmin`
  - `roles/storage.legacyBucketWriter`

### Kubernetes Resources
- Namespace: `observability`
- Service Account: `observability-sa` (with Workload Identity annotation)

### Workload Identity Binding
- Binds GCP SA to K8s SA for secure authentication

## Prerequisites

1. **Authentication**
   ```bash
   gcloud auth application-default login
   ```

2. **Enable Required APIs**
   ```bash
   gcloud services enable storage.googleapis.com
   gcloud services enable iam.googleapis.com
   gcloud services enable container.googleapis.com
   ```

3. **Get GKE Credentials**
   ```bash
   gcloud container clusters get-credentials observe-prod-cluster \
     --region=europe-west3 \
     --project=observe-472521
   ```

## Directory Structure

```
terraform/
├── main.tf
├── terraform.tfvars
└── README.md
```

## Usage

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply Configuration
```bash
terraform apply
```

Review the changes and type `yes` to confirm.

### 4. Verify Resources

**GCS Buckets:**
```bash
gcloud storage buckets list --filter="name:observe-472521-observability"
```

**GCP Service Account:**
```bash
gcloud iam service-accounts list --filter="email:gke-observability-sa@"
```

**Kubernetes Resources:**
```bash
kubectl get namespace monitoring
kubectl get serviceaccount -n monitoring observability-sa
kubectl describe serviceaccount -n monitoring observability-sa
```

**Verify Workload Identity Annotation:**
```bash
kubectl get serviceaccount observability-sa -n monitoring -o yaml | grep iam.gke.io
```

You should see:
```yaml
iam.gke.io/gcp-service-account: gke-observability-sa@observe-472521.iam.gserviceaccount.com
```

## Outputs

After applying, you'll see important outputs:

```bash
terraform output
```

Example output:
```
bucket_names = {
  "loki-admin" = "observe-472521-observability-loki-admin"
  "loki-chunks" = "observe-472521-observability-loki-chunks"
  "loki-ruler" = "observe-472521-observability-loki-ruler"
  "tempo-data" = "observe-472521-observability-tempo-data"
}
bucket_urls = {
  "loki-admin" = "gs://observe-472521-observability-loki-admin"
  "loki-chunks" = "gs://observe-472521-observability-loki-chunks"
  "loki-ruler" = "gs://observe-472521-observability-loki-ruler"
  "tempo-data" = "gs://observe-472521-observability-tempo-data"
}
gcp_service_account_email = "gke-observability-sa@observe-472521.iam.gserviceaccount.com"
kubernetes_service_account_name = "observability-sa"
namespace = "monitoring"
```

## Using in Helm Charts

You can now update your Helm values files with the bucket names:

**For Loki (`loki-values.yaml`):**
```yaml
loki:
  storage:
    bucketNames:
      chunks: observe-472521-observability-loki-chunks
      ruler: observe-472521-observability-loki-ruler
      admin: observe-472521-observability-loki-admin
    gcs:
      enableHttp: true

serviceAccount:
  create: false
  name: observability-sa
```

**For Tempo (`tempo-values.yaml`):**
```yaml
tempo:
  storage:
    trace:
      backend: gcs
      gcs:
        bucket_name: observe-472521-observability-tempo-data

serviceAccount:
  create: false
  name: observability-sa
```

## Testing Workload Identity

Test that a pod can authenticate to GCS:

```bash
kubectl run -it --rm test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=monitoring \
  -- gcloud storage buckets list --filter="name:observe-472521-observability"
```

If successful, you should see your buckets listed.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning:** This will delete all buckets and their contents. Make sure you have backups if needed.

## Troubleshooting

### Issue: "Permission denied" when accessing buckets

**Solution:** Verify Workload Identity binding:
```bash
gcloud iam service-accounts get-iam-policy \
  gke-observability-sa@observe-472521.iam.gserviceaccount.com
```

You should see a binding for `roles/iam.workloadIdentityUser` with the member:
```
serviceAccount:observe-472521.svc.id.goog[monitoring/observability-sa]
```

### Issue: Kubernetes provider authentication fails

**Solution:** Ensure you have valid credentials:
```bash
gcloud container clusters get-credentials observe-prod-cluster \
  --region=europe-west3 \
  --project=observe-472521
```

### Issue: Bucket already exists

**Solution:** If buckets were created manually, import them:
```bash
terraform import 'google_storage_bucket.observability_buckets["loki-chunks"]' observe-472521-observability-loki-chunks
```

## Next Steps

1. ✅ Apply this Terraform configuration
2. Update Helm values files with bucket names
3. Deploy Loki with: `helm install loki grafana/loki -f loki-values.yaml -n monitoring`
4. Deploy Tempo with: `helm install tempo grafana/tempo -f tempo-values.yaml -n monitoring`
5. Deploy Grafana and Prometheus as needed

## Security Notes

- All buckets have versioning enabled
- Uniform bucket-level access is enforced
- Lifecycle policy deletes objects after 90 days
- Workload Identity provides keyless authentication (no service account keys needed)