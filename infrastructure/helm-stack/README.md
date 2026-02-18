# NetBird Kubernetes Stack (Helm)

This stack provides a comprehensive, highly available deployment of NetBird on a Kubernetes cluster (EKS by default) using Terraform and Helm.

## Architecture

- **Control Plane**: Highly available NetBird Management, Signal, and Dashboard services.
- **Compute**: EKS Managed Node Groups with auto-scaling.
- **Database**: Managed PostgreSQL (RDS) with Multi-AZ HA.
- **Identity**: Integration with Keycloak for OIDC authentication.
- **Ingress**: Load balanced access to all NetBird services.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.6.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- AWS Credentials configured with appropriate permissions.

## Deployment

### 1. Initialize Terraform

```bash
cd infrastructure/helm-stack
terraform init
```

### 2. Configure Variables

Create a `terraform.tfvars` file based on your requirements:

```hcl
netbird_domain = "netbird.example.com"
keycloak_url   = "https://keycloak.example.com"
# ... other variables
```

### 3. Apply Infrastructure

```bash
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

### 4. Verify Deployment

```bash
# Get kubeconfig
aws eks update-kubeconfig --name netbird-cluster --region us-east-1

# Check pods
kubectl get pods -n netbird
```

## Customization

You can customize the deployment by modifying `variables.tf` or the Helm values template in `templates/values.yaml.tpl`.
