# NetBird Infrastructure Deployment Runbook

**Action Type**: Deployment | **Risk**: Medium | **Ops Book**: [Operations Book](../../operations-book/helm-stack/README.md)

## Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Tools Verified**: Terraform >= 1.0.0, kubectl, and Helm 3.x are installed.
- [ ] **Cluster Access**: `kubectl get nodes` confirms connection to the GKE cluster.
- [ ] **OIDC Readiness**: Keycloak URL is reachable and admin credentials are available.
- [ ] **DNS Access**: Control over the target domain for A record creation.

**STOP IF**: The Kubernetes cluster is unreachable or if Keycloak is down.

</details>

## Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Prepare Configuration

```bash
# Navigate to the terraform directory
cd infrastructure/helm-stack/terraform

# Initialize configuration from example
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars`** with your GCP, Keycloak, and NetBird settings. Ensure `db_type = "postgres"` and `create_db = true` for production HA.

### STEP 02 - Provision Infrastructure

```bash
# Initialize and apply terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### STEP 03 - Configure Networking

```bash
# Retrieve the Ingress-Nginx LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Create A Record**: Map `netbird.example.com` to the retrieved LoadBalancer IP in your DNS provider.

</details>

## Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Service Health

```bash
# Check all NetBird pods are Running
kubectl get pods -n netbird

# Expected Output:
# netbird-dashboard-xxx    1/1  Running
# netbird-management-xxx   1/1  Running
# netbird-signal-xxx       1/1  Running
```

### V02 - SSL/TLS Validation

```bash
# Verify Cert-Manager issued the certificate
kubectl get certificate -n netbird
```

### V03 - Initial Dashboard Login
1. Navigate to `https://netbird.example.com`.
2. Login using Keycloak admin credentials.
3. Verify that the peer list is accessible.

</details>

## Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### Infrastructure Destruction
If the deployment is corrupted beyond repair:
```bash
terraform destroy -auto-approve
```

### R02 - Manual Cleanup
```bash
kubectl delete namespace netbird
helm uninstall ingress-nginx -n ingress-nginx
```

</details>

