# NetBird Production Infrastructure (High Availability & High Security)

A production-grade Terraform + Ansible framework for deploying a highly available NetBird cluster on AWS, GCP, or Azure with a "Secure by Default" architecture.

## 🚀 Key Features

*   **Database Flexibility**: Choice of **SQLite** (Default), **PostgreSQL** (Managed/Existing), or **MySQL**.
*   **Security First**:
    *   **UFW Preservation**: Respects existing firewall rules; adds NetBird rules incrementally.
    *   **Private Isolation**: Management services bind to Private IPs only.
    *   **Cloud Security Groups**: Strict Inbound/Outbound rules managed by Terraform.
*   **Automated Identity**: Terraform automatically configures **Keycloak** Realms and Clients.
*   **Multi-Cloud**: Unified inventory for AWS, GCP, Azure, and Hybrid environments.

## 📚 Documentation

The full documentation is available in the `docs/` directory:

1.  [**Prerequisites**](docs/01-prerequisites.md): Cloud accounts, CLI tools, and quotas.
2.  [**Deployment Guide**](docs/02-deployment-guide.md): Step-by-step installation instructions.
3.  [**Configuration Reference**](docs/03-configuration-reference.md): Variables and file locations.
4.  [**Troubleshooting**](docs/04-troubleshooting.md): Diagnosis decision trees and logs.
5.  [**Upgrade Guide**](docs/05-upgrade-guide.md): How to update NetBird versions safely.
6.  [**Disaster Recovery**](docs/06-disaster-recovery.md): Backups and restoration procedures.
7.  [**Security Hardening**](docs/07-security-hardening.md): network segmentation and UFW details.
8.  [**Monitoring & Alerting**](docs/08-monitoring-alerting.md): Prometheus/Grafana setup.
9.  [**Architecture Decisions**](docs/09-architecture-decisions.md): Why we built it this way.
10. [**Glossary**](docs/10-glossary.md): Terminology.
11. [**Database Migration**](docs/11-database-migration-guide.md): Moving from SQLite to PostgreSQL.

## 🚀 Quick Start

### 1. Provision Infrastructure
```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Select your database backend in terraform.tfvars!
terraform init
terraform apply
```

### 2. Configure Servers
```bash
cd ../configuration
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

### 3. Verify Security
```bash
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/validate-security.yml
```

## 🔒 Security Architecture

This project implements a **Defense-in-Depth** strategy:

*   **Cloud Security Groups**: Block all traffic except necessary ports.
*   **Host Firewalls (UFW)**: Allow only specific internal IPs.
*   **Private Binding**: Services listen strictly on Private IPs.

See [07-security-hardening.md](docs/07-security-hardening.md) for details.
