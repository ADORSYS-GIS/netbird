# Google Cloud (GCP) Deployment Guide

This guide covers the specific requirements and configuration for deploying NetBird on Google Cloud Platform.

## Prerequisites

1.  **Google Cloud SDK**: Installed and configured (`gcloud`).
2.  **Project**: A valid GCP project ID.
3.  **Resources**: Existing Compute Engine instances.

## 1. Authentication

Authenticate with Application Default Credentials (ADC) to allow Terraform to manage resources:

```bash
gcloud auth application-default login
```

Verify your active project:

```bash
gcloud config get-value project
```

## 2. Infrastructure Setup

### VM Labeling (Critical)

Terraform discovers your instances using **labels**. Labels in GCP must be lowercase.

| Role | Label Key | Label Value (Default) | Description |
| :--- | :--- | :--- | :--- |
| **Management** | `role` | `netbird-management` | Runs Management, Signal, Dashboard |
| **Reverse Proxy** | `role` | `netbird-reverse-proxy` | Runs Caddy, handles SSL |
| **Relay** | `role` | `netbird-relay` | (Optional) Relay nodes |

### Firewall Rules

Ensure your VPC firewall rules allow:

*   **Public Access**: Ports `80` and `443` to the Reverse Proxy instances.
*   **Internal Access**: Port `80` (or your management port) between Reverse Proxy and Management instances.
*   **SSH**: Port `22` from your admin location.

## 3. Terraform Configuration

In your `terraform.tfvars`:

```hcl
cloud_provider = "gcp"
gcp_project    = "your-project-id"
gcp_region     = "us-central1"

# Update filters if you used different labels
gcp_label_filters = {
  management    = { key = "role", value = "netbird-management" }
  reverse_proxy = { key = "role", value = "netbird-reverse-proxy" }
  relay         = { key = "role", value = "netbird-relay" }
}
```

## Next Steps

Return to the [VM Deployment Guide](../../infrastructure/ansible-stack/docs/getting-started.md) to continue with the Terraform and Ansible execution.
