# Infrastructure

Terraform infrastructure code for NetBird deployment automation.

## Ansible Stack

Deploy NetBird on existing VMs using Terraform for discovery and Ansible for configuration.

**Directory**: `ansible-stack/`

**Usage**:
```bash
cd ansible-stack
terraform init
terraform plan
terraform apply
```

This generates an Ansible inventory at `../../configuration/ansible/inventory/terraform_inventory.yaml`.

Then deploy with Ansible:
```bash
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

**Documentation**: See [ansible-stack/docs/](./ansible-stack/docs/) for complete guide.

## Modules

### inventory

Multi-cloud VM discovery supporting AWS, GCP, Azure, and manual hosts.

### database

Unified database backend supporting SQLite, PostgreSQL, and MySQL.

### keycloak

Keycloak SSO configuration for NetBird authentication.

## Testing

```bash
# From project root
make test-terraform

# Or manually
cd ansible-stack
terraform fmt -check -recursive
terraform validate
```

## Related Documentation

- [Deployment Guide](./ansible-stack/docs/getting-started.md) - Complete deployment walkthrough
- [Configuration Reference](./ansible-stack/docs/configuration-reference.md) - All variables
- [Architecture Documentation](../docs/architecture.md) - architecture and operations
