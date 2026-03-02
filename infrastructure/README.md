# NetBird Infrastructure

Terraform modules and configurations for deploying NetBird.

## Stacks

### Ansible Stack (`ansible-stack/`)

VM-based deployment using Terraform + Ansible + Docker Compose.

**Use for:**
- Production deployments on VMs
- Multi-cloud or on-premise infrastructure
- Full control over configuration

**Features:**
- High availability with HAProxy load balancing
- Automatic TLS certificates via ACME
- PgBouncer connection pooling
- Multi-node management cluster

[Documentation](ansible-stack/README.md)

### Helm Stack (`helm-stack/`)

Kubernetes-native deployment using Helm charts.

**Use for:**
- Kubernetes environments
- Cloud-native deployments
- Container orchestration platforms

[Documentation](helm-stack/README.md)

## Modules

Reusable Terraform modules:

- `modules/database/` - Database configuration (SQLite, PostgreSQL)
- `modules/inventory/` - Host inventory management
- `modules/keycloak/` - Keycloak SSO integration

## Quick Start

Choose your deployment stack:

```bash
# VM-based deployment
cd ansible-stack
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply

# Kubernetes deployment
cd helm-stack
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply
```

## Documentation

- [NetBird Official Docs](https://docs.netbird.io/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
