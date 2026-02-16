# 01 - Prerequisites

Before starting the deployment of the NetBird infrastructure, ensure you have the following prerequisites met.

## System Requirements

### Workstation
*   **OS**: Linux, macOS, or Windows (WSL2)
*   **Terraform**: >= 1.0 ([Install Guide](https://developer.hashicorp.com/terraform/downloads))
*   **Ansible**: >= 2.10 ([Install Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
*   **Git**: Latest version
*   **Cloud CLI**:
    *   AWS CLI (if using AWS)
    *   gcloud CLI (if using GCP)
    *   Azure CLI (if using Azure)

### Cloud Provider Quotas
Ensure your cloud account has sufficient quotas for:
*   **VMs**: Minimum 3 vCPUs, 4GB RAM total (e.g., t3.small instances)
*   **Public IP**: 1 Static Public IP (Elastic IP) for the Reverse Proxy
*   **Networking**: Ability to create Security Groups / Firewall Rules

### External Dependencies
*   **Domain Name**: A valid domain name (e.g., `netbird.example.com`) pointing to the Reverse Proxy's Public IP (configured after Terraform run).
*   **SSL**: Caddy will automatically provision Let's Encrypt certificates. Ensure Port 80/443 are open (handled by Terraform).

## Authentication

### AWS
```bash
aws configure
# Verify
aws sts get-caller-identity
```

### GCP
```bash
gcloud auth login
gcloud auth application-default login
# Verify
gcloud projects list
```

### Azure
```bash
az login
# Verify
az account show
```

## Next Steps
Proceed to [02-deployment-guide.md](./02-deployment-guide.md).
