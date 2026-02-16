# Ansible Stack Documentation

Deployment documentation for the Terraform + Ansible deployment method.

## Quick Navigation

### Getting Started
1. **[Getting Started](./getting-started.md)** - Complete deployment guide with prerequisites
2. **[Configuration Reference](./configuration-reference.md)** - Variable customization options

### Operations
- **[Upgrade Guide](./upgrade-guide.md)** - Procedures for upgrading NetBird versions
- **[Troubleshooting](./troubleshooting.md)** - Common issues and solutions
- **[Database Migration](./database-migration.md)** - Switching database backends

## Deployment Overview

The **Ansible Stack** deploys NetBird on existing VMs using:
- **Terraform**: VM discovery (AWS/GCP/Azure/manual), database setup, Keycloak configuration
- **Ansible**: Service installation, Docker setup, firewall configuration

## Quick Start

```bash
# 1. Configure Terraform
cd infrastructure/ansible-stack
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # Edit cloud_provider, tags, domain, etc.

# 2. Run Terraform
terraform init
terraform apply

# 3. Run Ansible
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml

# 4. Verify
curl https://netbird.example.com/health
```

## Documentation Sections

### Deployment Guides
- **Prerequisites**: Tools, credentials, system requirements
- **Getting Started**: Complete deployment walkthrough
- **Configuration Reference**: All available variables and options

### Operational Guides
- **Upgrade Guide**: Version upgrades and rollback procedures
- **Troubleshooting**: Common issues and diagnostic steps
- **Database Migration**: Switching between SQLite, PostgreSQL, MySQL

## Related Documentation

- **[General Architecture](../../../docs/architecture.md)** - System design and architecture decisions
- **[Operations Guides](../../../docs/operations/)** - Monitoring, security, disaster recovery
- **[Ansible Configuration](../../../configuration/ansible/README.md)** - Playbook and role details
- **[Module Documentation](../../modules/)** - Terraform module references

## Support

For deployment issues:
1. Check [Troubleshooting Guide](./troubleshooting.md)
2. Review prerequisites in [Getting Started](./getting-started.md)
3. Review Terraform/Ansible logs

For general NetBird usage:
- [NetBird Official Docs](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
