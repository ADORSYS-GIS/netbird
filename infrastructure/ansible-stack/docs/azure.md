# Azure Deployment Guide

This guide covers the specific requirements and configuration for deploying NetBird on Microsoft Azure.

## Prerequisites

1.  **Azure CLI**: Installed and configured (`az`).
2.  **Subscription**: Active Azure subscription.
3.  **Resources**: Existing Virtual Machines in a Resource Group.

## 1. Authentication

Log in via the Azure CLI to establish a session for Terraform:

```bash
az login
```

Verify your subscription:

```bash
az account show
```

## 2. Infrastructure Setup

### VM Tagging (Critical)

Terraform discovers your VMs using **tags**.

| Role | Tag Key | Tag Value (Default) | Description |
| :--- | :--- | :--- | :--- |
| **Management** | `Role` | `netbird-management` | Runs Management, Signal, Dashboard |
| **Reverse Proxy** | `Role` | `netbird-reverse-proxy` | Runs Caddy, handles SSL |
| **Relay** | `Role` | `netbird-relay` | (Optional) Relay nodes |

### Network Security Groups (NSG)

Configure your NSGs to allow:

*   **Reverse Proxy**: Inbound `80` and `443` from Internet.
*   **Internal**: Inbound `80` (Management) from Reverse Proxy subnet.
*   **SSH**: Inbound `22` from your IP.

## 3. Terraform Configuration

In your `terraform.tfvars`:

```hcl
cloud_provider       = "azure"
azure_resource_group = "your-resource-group-name"

# Update filters if you used different tags
azure_tag_filters = {
  management    = { Name = "tag:Role", Values = ["netbird-management"] }
  reverse_proxy = { Name = "tag:Role", Values = ["netbird-reverse-proxy"] }
  relay         = { Name = "tag:Role", Values = ["netbird-relay"] }
}
```

## Next Steps

Return to the [VM Deployment Guide](../../infrastructure/ansible-stack/docs/getting-started.md) to continue with the Terraform and Ansible execution.
