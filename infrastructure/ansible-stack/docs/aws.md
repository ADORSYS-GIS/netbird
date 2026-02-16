# AWS Deployment Guide

This guide covers the specific requirements and configuration for deploying NetBird on Amazon Web Services (AWS).

## Prerequisites

1.  **AWS CLI**: Installed and configured.
2.  **Permissions**: Access to read EC2 instances and managing Security Groups (if utilizing managed security groups).
3.  **Resources**: Existing EC2 instances for:
    *   Management (Minimum 2 for HA)
    *   Reverse Proxy (Minimum 1 with a Public IP/Elastic IP)

## 1. Authentication

NetBird's infrastructure automation uses the standard AWS CLI credentials chain.

Run `aws configure` to set up your credentials:

```bash
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: us-east-1
# Default output format [None]: json
```

Verify your identity:

```bash
aws sts get-caller-identity
```

## 2. Infrastructure Setup

### VM Tagging (Critical)

Terraform discovers your EC2 instances using **tags**. You must tag your instances so Terraform can assign them the correct roles.

| Role | Tag Key | Tag Value (Default) | Count | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Management** | `Role` | `netbird-management` | 1+ (3 Rec.) | Runs Management, Signal, Dashboard |
| **Reverse Proxy** | `Role` | `netbird-reverse-proxy` | 1+ | Runs Caddy, handles SSL |
| **Relay** | `Role` | `netbird-relay` | 0+ | (Optional) Relay nodes |

> **Note**: These tag values are configurable in `terraform.tfvars` if you use a different naming convention.

### Security Groups

Ensure your security groups allow the following traffic:

*   **Reverse Proxy**:
    *   Inbound `443/tcp` (HTTPS) from `0.0.0.0/0`
    *   Inbound `80/tcp` (HTTP) from `0.0.0.0/0` (for ACME challenges)
    *   Inbound `22/tcp` (SSH) from your admin IP
    *   Outbound `80/tcp` to Management Nodes (Private IP)

*   **Management Nodes**:
    *   Inbound `80/tcp` from Reverse Proxy SG (Private IP)
    *   Inbound `22/tcp` (SSH) from your admin IP

## 3. Terraform Configuration

In your `terraform.tfvars`:

```hcl
cloud_provider = "aws"
aws_region     = "us-east-1"  # Replace with your region

# Update filters if you used different tags
aws_tag_filters = {
  management    = { Name = "tag:Role", Values = ["netbird-management"] }
  reverse_proxy = { Name = "tag:Role", Values = ["netbird-reverse-proxy"] }
  relay         = { Name = "tag:Role", Values = ["netbird-relay"] }
}
```

## Next Steps

Return to the [VM Deployment Guide](../../infrastructure/ansible-stack/docs/getting-started.md) to continue with the Terraform and Ansible execution.
