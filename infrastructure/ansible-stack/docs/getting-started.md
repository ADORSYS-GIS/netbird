# VM Deployment Guide

This guide details the deployment of NetBird on existing Virtual Machines (VMs) using Terraform for discovery and Ansible for configuration.

## Prerequisites

Before starting, ensure you have completed the **Cloud-Specific Setup** for your provider:

*   [**AWS Setup Guide**](./aws.md)
*   [**Google Cloud Setup Guide**](./google-cloud.md)
*   [**Azure Setup Guide**](./azure.md)

### Required Tools

- **Terraform**: >= 1.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible**: >= 2.10 ([Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **Git**: Latest version

### External Requirements

- **Domain Name**: A valid domain (e.g., `vpn.example.com`) pointed to your Reverse Proxy public IP.
- **Keycloak/Zitadel**: An existing OIDC provider instance.

## Deployment Overview

The deployment consists of three phases:

1.  **Infrastructure Discovery** (Terraform)
2.  **DNS Configuration**
3.  **Server Configuration** (Ansible)

## Phase 1: Infrastructure Discovery

Terraform discovers existing VMs based on the tags/labels configures in your Cloud Setup.

### Steps

1.  **Navigate to infrastructure directory**:
    ```bash
    cd infrastructure/ansible-stack
    ```

2.  **Initialize Terraform**:
    ```bash
    terraform init
    ```

3.  **Configure variables**:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    nano terraform.tfvars
    ```

    **Key Variables**:
    -   `cloud_provider`: `aws`, `gcp`, `azure`
    -   `netbird_domain`: Your domain (e.g., `vpn.example.com`)
    -   `*_tag_filters`: Ensure these match the tags you set on your VMs.

4.  **Review the plan**:
    ```bash
    terraform plan
    ```
    *Verify that Terraform has discovered the correct number of Management and Reverse Proxy nodes.*

5.  **Apply configuration**:
    ```bash
    terraform apply
    ```

### Terraform Outputs

After a successful apply, Terraform generates:

-   **Ansible inventory**: `../../configuration/ansible/inventory/terraform_inventory.yaml`
-   **Database connection details**: (If a managed DB was created)
-   **Keycloak credentials**: (If Keycloak was configured)

## Phase 2: DNS Configuration

1.  **Get Reverse Proxy IP**:
    ```bash
    terraform output reverse_proxy_public_ip
    ```

2.  **Update DNS**:
    Create an `A` record for your `netbird_domain` (e.g., `vpn.example.com`) pointing to this IP.

3.  **Verify Propagation**:
    ```bash
    dig vpn.example.com +short
    ```

## Phase 3: Server Configuration

Ansible installs and configures NetBird services on the discovered VMs.

### Steps

1.  **Navigate to configuration directory**:
    ```bash
    cd ../../configuration/ansible
    ```

2.  **Test Connectivity**:
    ```bash
    ansible -i inventory/terraform_inventory.yaml all -m ping
    ```

3.  **Run Deployment Playbook**:
    ```bash
    ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
    ```

    **What happens**:
    -   Docker & Caddy installation
    -   NetBird services deployment (Management, Signal, Dashboard)
    -   Automatic HTTPS provisioning

## Verification

### Service Health

1.  **Check Health Endpoint**:
    ```bash
    curl -f https://vpn.example.com/health
    ```
    *Expected output: `{"status":"ok"}`*

2.  **Access Dashboard**:
    Open `https://vpn.example.com` in your browser.

### Security Validation

Run the automated security check playbook:

```bash
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/validate-security.yml
```

## Troubleshooting

If you encounter issues, refer to the [Troubleshooting Guide](./troubleshooting.md).
