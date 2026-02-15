# Infrastructure

Terraform and Ansible automation for NetBird deployment.

## Components

### Terraform (`terraform/`)
Multi-cloud VM discovery and Ansible inventory generation.

**Documentation**: [terraform/docs/inventory-management.md](terraform/docs/inventory-management.md)

### Ansible (`ansible/`)
Automated deployment to discovered VMs.

**Documentation**: [ansible/docs/deployment.md](ansible/docs/deployment.md)

## Workflow

```mermaid
graph LR
    A[Tag VMs] --> B[Terraform Discover]
    B --> C[Generate Inventory]
    C --> D[Ansible Deploy]
    D --> E[NetBird Running]
```

## Quick Start

```bash
# 1. Terraform: Discover VMs
cd terraform
terraform init
terraform apply

# 2. Ansible: Deploy NetBird
cd ../../configuration/ansible
ansible-playbook site.yaml
```
