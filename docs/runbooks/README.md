# NetBird Infrastructure | Runbook Index

**Tactical Procedures for Deployment, Maintenance, and Incidents**

## Lifecycle & Deployment
Standard procedures for deploying and maintaining production environments.

### Helm Stack (Kubernetes/GKE)
- [**Helm Stack Deployment**](./helm-stack/deployment.md)
- [**Helm Stack Upgrade**](./helm-stack/upgrade.md)

### Ansible Stack (VMs/Docker)
- [**Ansible Stack Deployment**](./ansible-stack/deployment.md)
- [**Ansible Stack Upgrade**](./ansible-stack/upgrade.md)

## Stack-Specific Operations

### Helm Stack (Kubernetes)
- [**Backup & Restore**](./helm-stack/backup-restore.md)
- [**Troubleshooting**](./helm-stack/troubleshooting.md)
- [**Scaling Operations**](./helm-stack/scaling.md)
- [**AWS VPC Integration**](./helm-stack/aws-vpc-integration.md)
- [**Keycloak OIDC Integration**](./helm-stack/keycloak-integration.md)

### Ansible Stack (Docker)
- [**Backup & Restore**](./ansible-stack/backup-restore.md)
- [**Troubleshooting**](./ansible-stack/troubleshooting-restoration.md)
- [**Database HA & Pooling**](./ansible-stack/database-management.md)
- [**Failover Testing**](./ansible-stack/failover-testing.md)
