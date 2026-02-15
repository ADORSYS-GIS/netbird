# Terraform Inventory Management

## Overview

Terraform discovers existing VMs across AWS, GCP, and Azure, then generates an Ansible inventory file.

## Structure

```
infrastructure/terraform/
├── versions.tf              # Provider constraints
├── variables.tf             # Input variables
├── outputs.tf               # Inventory data export
├── main.tf                  # Multi-cloud orchestration
├── terraform.tfvars.example # Configuration template
├── modules/
│   ├── inventory-aws/       # AWS EC2 discovery
│   ├── inventory-gcp/       # GCP Compute discovery
│   └── inventory-azure/     # Azure VM discovery
└── templates/
    └── inventory.yaml.tpl   # Ansible inventory template
```

## Quick Start

### 1. Configure Cloud Providers

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Example**:
```hcl
use_aws = true
aws_region = "us-east-1"
aws_tag_key = "NetBirdRole"
aws_tag_values = ["netbird-primary"]
```

### 2. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify Inventory

```bash
cat ../../configuration/ansible/inventory/terraform_inventory.yaml
```

## Cloud Provider Configuration

### AWS

**Requirements**:
- VMs tagged with `NetBirdRole=netbird-primary`
- AWS credentials configured

**Variables**:
```hcl
use_aws = true
aws_region = "us-east-1"
aws_tag_key = "NetBirdRole"
aws_tag_values = ["netbird-primary"]
```

### GCP

**Requirements**:
- VMs labeled with `netbird-role=netbird-primary`
- `gcloud` CLI installed and authenticated

**Variables**:
```hcl
use_gcp = true
gcp_project = "my-project"
gcp_region = "us-central1"
gcp_label_key = "netbird-role"
```

### Azure

**Requirements**:
- VMs tagged with `NetBirdRole=netbird-primary`
- `az` CLI installed and authenticated

**Variables**:
```hcl
use_azure = true
azure_subscription_id = "..."
azure_resource_group = "netbird-rg"
azure_tag_key = "NetBirdRole"
```

## Inventory Output

Generated inventory structure:

```yaml
all:
  children:
    netbird_servers:
      hosts:
        vm-1:
          ansible_host: 1.2.3.4
          cloud: aws
          region: us-east-1
```

## Troubleshooting

### No VMs Discovered

```bash
# Verify VM tags
aws ec2 describe-instances --filters "Name=tag:NetBirdRole,Values=netbird-primary"
```

### Provider Authentication

```bash
# AWS
aws configure

# GCP
gcloud auth application-default login

# Azure
az login
```

## Technical Specification

**Version**: 1.0  
**Last Audit**: 2026-02-15
