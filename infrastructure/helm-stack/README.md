# NetBird Helm Stack Infrastructure

Terraform configuration for deploying NetBird on Google Kubernetes Engine (GKE) with Keycloak integration.

## Overview

This Terraform stack:
- Provisions GKE cluster (optional - can use existing)
- Deploys NetBird via Helm chart
- Configures Cloud SQL PostgreSQL (optional)
- Sets up Keycloak realm and clients automatically
- Configures Ingress and TLS certificates

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GKE Cluster                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Dashboard  │  │  Management │  │   Signal    │              │
│  │   (nginx)   │  │    (API)    │  │   (gRPC)    │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │                                      │
│                    ┌─────┴─────┐                                │
│                    │  Ingress  │                                │
│                    │  (nginx)  │                                │
│                    └─────┬─────┘                                │
│                          │                                      │
│  ┌───────────────────────┼───────────────────────┐              │
│  │                       │                       │              │
│  │  ┌─────────────┐  ┌───┴───┐  ┌─────────────┐ │               │
│  │  │    Relay    │  │  TLS  │  │   Secrets   │ │               │
│  │  │   (TURN)    │  │(cert- │  │ (k8s secret)│ │               │
│  │  └─────────────┘  │manager│  └─────────────┘ │               │
│  │                   └───────┘                   │              │
│  └───────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────┐                ┌─────────────────┐
│    Keycloak     │                │   Cloud SQL     │
│  (External IdP) │                │  (PostgreSQL)   │
└─────────────────┘                │   or SQLite     │
                                   └─────────────────┘
```

## Prerequisites

1. **GKE Cluster** - Running Kubernetes cluster (or let Terraform create one)
2. **Keycloak** - External Keycloak instance accessible from the cluster
3. **DNS** - Domain configured to point to your ingress controller
4. **kubectl** - Configured to access your cluster
5. **Helm** - Helm 3.10+ installed

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Essential Variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `netbird_domain` | Primary domain | `vpn.example.com` |
| `netbird_chart_version` | NetBird Helm chart version | `1.0.0` |
| `keycloak_url` | Keycloak URL | `https://auth.example.com` |
| `keycloak_admin_username` | Keycloak admin user | `admin` |
| `keycloak_admin_password` | Keycloak admin password | `secure-password` |

### 2. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n netbird

# Check ingress
kubectl get ingress -n netbird

# Test health endpoint
curl -f https://your-domain.com/health
```

## Configuration Options

### Database Options

**SQLite (Development/Testing):**
```hcl
db_type       = "sqlite"
create_db     = false
replica_count = 1  # Must be 1 for SQLite
```

**Cloud SQL PostgreSQL (Production - New Instance):**
```hcl
db_type          = "postgres"
create_db        = true
db_password      = "secure-password"
db_instance_tier = "db-custom-2-7680"
replica_count    = 3
```

**External/Existing PostgreSQL:**
```hcl
db_type         = "postgres"
create_db       = false
external_db_dsn = "postgresql://user:pass@host:5432/dbname"
replica_count   = 3
```

### High Availability

For production deployments:
```hcl
db_type       = "postgres"
create_db     = true
replica_count = 3
```

### Keycloak Integration

This configuration automatically creates:
- NetBird Realm
- Dashboard Client (Public)
- Backend Client (Confidential with service account)
- Required scopes (api, groups)
- Audience mapper for proper token validation
- Service account roles for user management

## Outputs

After `terraform apply`, you'll get:

- `netbird_url` - NetBird dashboard URL
- `keycloak_realm` - Keycloak realm name
- `keycloak_client_id` - Dashboard client ID
- `backend_client_secret` - Backend client secret

## Operations

### Update Configuration

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Apply changes
terraform apply
```

### Upgrade NetBird

```bash
# Update chart version in terraform.tfvars
netbird_chart_version = "1.1.0"

# Apply upgrade
terraform apply
```

### Scale Replicas

```bash
# Update replica count in terraform.tfvars
replica_count = 5

# Apply changes
terraform apply
```

### Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n netbird
```

### View Logs

```bash
# Management logs
kubectl logs -n netbird -l app.kubernetes.io/component=management

# Dashboard logs
kubectl logs -n netbird -l app.kubernetes.io/component=dashboard

# Signal logs
kubectl logs -n netbird -l app.kubernetes.io/component=signal
```

### Verify Keycloak Configuration

1. Log into Keycloak admin console
2. Navigate to the NetBird realm
3. Verify clients are created with correct redirect URIs
4. Check that the backend service account has required roles

### Check Ingress

```bash
kubectl describe ingress -n netbird
```

## File Structure

```
infrastructure/helm-stack/
├── main.tf              # Provider and EKS/GKE configuration
├── variables.tf         # Input variable definitions
├── terraform.tfvars     # Your configuration values
├── outputs.tf           # Output definitions
├── backend.tf           # Terraform backend configuration
├── keycloak.tf          # Keycloak realm and clients
├── database.tf          # Cloud SQL and secrets
├── helm_netbird.tf      # Helm release for NetBird
├── ingress_dashboard.tf # Ingress configuration
└── values-official.yaml # Helm values template
```

## Security Considerations

1. **Secrets Management**: Store sensitive values in a secure location (e.g., GCP Secret Manager, AWS Secrets Manager)
2. **Network Policies**: Consider implementing Kubernetes network policies
3. **RBAC**: Review and restrict Kubernetes RBAC permissions
4. **Database**: Use private IP and VPC peering for Cloud SQL in production
5. **TLS**: Ensure cert-manager is properly configured for automatic certificate renewal

## Related Documentation

### Deployment
- [Helm Stack Deployment Runbook](../../docs/runbooks/helm-stack/deployment.md) - Step-by-step deployment
- [Helm Stack Upgrade Runbook](../../docs/runbooks/helm-stack/upgrade.md) - Upgrade procedures

### Operations
- [Operations Book](../../docs/operations-book/helm-stack/README.md) - Operations guide
- [Troubleshooting](../../docs/runbooks/helm-stack/troubleshooting.md) - Common issues
- [Scaling Guide](../../docs/runbooks/helm-stack/scaling.md) - Scaling procedures

### Integration
- [AWS VPC Integration](../../docs/runbooks/helm-stack/aws-vpc-integration.md) - AWS VPC setup
- [Keycloak Integration](../../docs/runbooks/helm-stack/keycloak-integration.md) - Keycloak OIDC setup

## Support

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird Helm Chart](https://artifacthub.io/packages/helm/netbird/netbird)
- [Keycloak IdP Guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak)
