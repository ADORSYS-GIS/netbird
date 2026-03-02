# NetBird Infrastructure Terraform

This Terraform configuration deploys NetBird on Google Kubernetes Engine (GKE) with Keycloak as the identity provider.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GKE Cluster                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Dashboard  │  │  Management │  │   Signal    │             │
│  │   (nginx)   │  │    (API)    │  │   (gRPC)    │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │                                      │
│                    ┌─────┴─────┐                                │
│                    │  Ingress  │                                │
│                    │  (nginx)  │                                │
│                    └─────┬─────┘                                │
│                          │                                      │
│  ┌───────────────────────┼───────────────────────┐             │
│  │                       │                       │             │
│  │  ┌─────────────┐  ┌───┴───┐  ┌─────────────┐ │             │
│  │  │    Relay    │  │  TLS  │  │   Secrets   │ │             │
│  │  │   (TURN)    │  │(cert- │  │ (k8s secret)│ │             │
│  │  └─────────────┘  │manager│  └─────────────┘ │             │
│  │                   └───────┘                   │             │
│  └───────────────────────────────────────────────┘             │
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

1. **GKE Cluster** - Running Kubernetes cluster
2. **Keycloak** - External Keycloak instance accessible from the cluster
3. **DNS** - Domain configured to point to your ingress controller
4. **Cert-Manager** - For automatic TLS certificates (optional, can be installed by this config)
5. **Ingress Controller** - nginx-ingress recommended (optional, can be installed by this config)

## Quick Start

1. **Copy and configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan the deployment:**
   ```bash
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply
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
db_type         = "postgres"
create_db       = true
db_password      = "secure-password"
db_instance_tier = "db-custom-2-7680"
replica_count    = 3
```

**External/Existing PostgreSQL:**
```hcl
db_type         = "postgres"
create_db       = false
external_db_dsn = "postgresql://user:pass@host:5432/dbname"
replica_count    = 3
```

### Keycloak Integration

This configuration automatically creates:
- NetBird Realm
- Dashboard Client (Public)
- Backend Client (Confidential with service account)
- Required scopes (api, groups)
- Audience mapper for proper token validation
- Service account roles for user management

### High Availability

For production deployments:
```hcl
db_type       = "postgres"
create_db     = true
replica_count = 3
```

## Files

| File | Description |
|------|-------------|
| `main.tf` | Provider configuration and random resources |
| `variables.tf` | Input variable definitions |
| `terraform.tfvars` | Your configuration values |
| `keycloak.tf` | Keycloak realm, clients, and roles |
| `database.tf` | Cloud SQL and Kubernetes secrets |
| `helm_netbird.tf` | Helm release for NetBird |
| `values-official.yaml` | Helm values template |
| `outputs.tf` | Output values |

## Connecting Clients

After deployment, connect NetBird clients using:

```bash
# Install NetBird client
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Connect to your management server
netbird up --management-url https://your-netbird-domain.com
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n netbird
```

### View logs
```bash
# Management logs
kubectl logs -n netbird -l app.kubernetes.io/component=management

# Dashboard logs
kubectl logs -n netbird -l app.kubernetes.io/component=dashboard
```

### Verify Keycloak configuration
1. Log into Keycloak admin console
2. Navigate to the NetBird realm
3. Verify clients are created with correct redirect URIs
4. Check that the backend service account has required roles

## Security Considerations

1. **Secrets Management**: Store sensitive values in a secure location (e.g., GCP Secret Manager)
2. **Network Policies**: Consider implementing Kubernetes network policies
3. **RBAC**: Review and restrict Kubernetes RBAC permissions
4. **Database**: Use private IP and VPC peering for Cloud SQL in production

## References

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird Helm Chart](https://artifacthub.io/packages/helm/netbird/netbird)
- [Keycloak IdP Guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak)
