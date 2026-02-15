# Terraform Infrastructure

Multi-cloud VM inventory management for NetBird deployment.

## Structure

```
infrastructure/terraform/
├── main.tf                  # Multi-cloud orchestration
├── variables.tf             # Input variables
├── outputs.tf               # Inventory export
├── versions.tf              # Provider constraints
├── terraform.tfvars.example # Configuration template
├── modules/
│   ├── inventory-aws/       # AWS EC2 discovery
│   ├── inventory-gcp/       # GCP Compute discovery
│   └── inventory-azure/     # Azure VM discovery
└── templates/
    └── inventory.yaml.tpl   # Ansible inventory template
```

## Quick Start

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Initialize
terraform init

# 3. Generate inventory
terraform apply
```

## Output

Generates `../../configuration/ansible/inventory/terraform_inventory.yaml` for Ansible.

## Documentation

- [Inventory Management Guide](docs/inventory-management.md)
