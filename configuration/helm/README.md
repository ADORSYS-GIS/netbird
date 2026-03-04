# NetBird Helm Configuration

Helm values and configuration files for deploying NetBird on Kubernetes.

## Overview

This directory contains Helm values files for deploying NetBird using the official NetBird Helm chart. The configuration is managed by Terraform in `infrastructure/helm-stack/`.

## Files

| File | Description |
|------|-------------|
| `values-official.yaml` | Official NetBird Helm chart values template |

## Usage

### Prerequisites

- Kubernetes cluster (1.23+)
- Helm 3.10+
- kubectl configured
- Terraform (for infrastructure deployment)

### Deployment

The Helm deployment is managed through Terraform. See `infrastructure/helm-stack/README.md` for deployment instructions.

```bash
cd infrastructure/helm-stack
terraform init
terraform plan
terraform apply
```

### Configuration

The `values-official.yaml` file is a Terraform template that gets populated with variables from `infrastructure/helm-stack/terraform.tfvars`.

Key configuration areas:

| Section | Description |
|---------|-------------|
| `global` | Global settings (domain, replicas) |
| `management` | Management service configuration |
| `signal` | Signal server configuration |
| `dashboard` | Web UI configuration |
| `relay` | Relay server configuration (optional) |
| `ingress` | Ingress and TLS configuration |
| `database` | Database configuration (SQLite or PostgreSQL) |

### Customization

To customize the deployment:

1. Edit `infrastructure/helm-stack/terraform.tfvars`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

## Related Documentation

| Document | Description |
|----------|-------------|
| [Helm Stack Infrastructure](../../infrastructure/helm-stack/README.md) | Terraform infrastructure |
| [Helm Deployment Runbook](../../docs/runbooks/helm-stack/deployment.md) | Deployment procedures |
| [Helm Upgrade Runbook](../../docs/runbooks/helm-stack/upgrade.md) | Upgrade procedures |
| [Operations Book](../../docs/operations-book/helm-stack/README.md) | Operations guide |

## Support

For issues or questions:
- Check the [troubleshooting guide](../../docs/runbooks/helm-stack/troubleshooting.md)
- Review the [official NetBird documentation](https://docs.netbird.io/)
- Open an issue in the project repository
