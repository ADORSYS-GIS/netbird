# NetBird Ansible Stack Infrastructure

Terraform configuration for discovering and inventorying VMs for NetBird deployment.

## Overview

This Terraform stack:
- Discovers existing VMs across AWS, GCP, Azure, or on-premise via tags/labels
- Generates Ansible inventory with all required variables
- Optionally triggers Ansible deployment automatically

## Architecture

```
Internet → HAProxy/Caddy → Management Cluster → PostgreSQL + PgBouncer
                         → Relay Servers
```

**Components:**
- **Management Nodes**: Run NetBird Management, Signal, and Dashboard services
- **Reverse Proxy**: HAProxy or Caddy for load balancing and TLS termination
- **Database**: PostgreSQL (production) or SQLite (development)
- **PgBouncer**: Optional connection pooling for PostgreSQL
- **Relay Servers**: Optional TURN servers for NAT traversal

## Prerequisites

**Local Machine:**
- Terraform >= 1.6.0
- Ansible >= 2.10
- SSH key for server access

**Target Infrastructure:**
- Existing VMs (Ubuntu 20.04+)
- SSH key-based authentication
- Public + Private IP addresses
- Minimum: 2vCPU, 4GB RAM per management node

**External Services:**
- Keycloak (Identity Provider)
- PostgreSQL database (for production)
- DNS configured for your domain

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Essential Variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `netbird_domain` | Primary domain | `vpn.example.com` |
| `netbird_version` | NetBird version | `0.31.0` |
| `netbird_hosts` | VM definitions | See example below |
| `database_type` | Database engine | `postgresql` or `sqlite` |
| `keycloak_url` | Keycloak URL | `https://auth.example.com` |

**Example Host Definition:**
```hcl
netbird_hosts = {
  management = {
    hosts = {
      "mgmt-01" = { public_ip = "203.0.113.10", private_ip = "10.0.1.10" }
      "mgmt-02" = { public_ip = "203.0.113.11", private_ip = "10.0.1.11" }
    }
  }
  reverse_proxy = {
    hosts = {
      "proxy-01" = { public_ip = "203.0.113.20", private_ip = "10.0.1.20" }
    }
  }
}
```

See `terraform.tfvars.example` for complete configuration options.

### 2. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration (generates inventory)
terraform apply
```

This creates `../../configuration/ansible/inventory/terraform_inventory.yaml`.

### 3. Deploy with Ansible

**Option A: Manual Deployment (Recommended)**
```bash
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

**Option B: Automatic Deployment**
Set `auto_deploy = true` in `terraform.tfvars` to run Ansible automatically after Terraform.

### 4. Verify Deployment

```bash
curl -f https://your-domain.com/health
```

## Configuration Options

### Deployment Modes

**Manual (default):**
```hcl
auto_deploy = false  # Terraform generates inventory only
```

**Automatic:**
```hcl
auto_deploy = true  # Terraform runs Ansible automatically
```

### High Availability

**Enable PgBouncer Connection Pooling:**
```hcl
enable_pgbouncer = true
pgbouncer_pool_mode = "transaction"
pgbouncer_default_pool_size = 25
```

### Database Configuration

**PostgreSQL (Production):**
```hcl
database_type = "postgresql"
db_host = "db.example.com"
db_port = 5432
db_name = "netbird"
db_user = "netbird"
db_password = "secure-password"
db_sslmode = "require"
```

**SQLite (Development):**
```hcl
database_type = "sqlite"
```

## Outputs

After `terraform apply`, you'll get:

- `management_nodes` - Management node IPs
- `proxy_nodes` - Proxy node IPs
- `relay_nodes` - Relay node IPs (if configured)
- `inventory_file` - Path to generated Ansible inventory

## Operations

### Update Configuration

```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Apply changes
terraform apply

# Redeploy with Ansible
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

### Upgrade NetBird

```bash
# Update version in terraform.tfvars
netbird_version = "0.32.0"

# Regenerate inventory
terraform apply

# Run upgrade playbook
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/upgrade.yml
```

### Cleanup

```bash
# Remove services (Ansible)
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/cleanup.yml

# Destroy Terraform state
cd ../../infrastructure/ansible-stack
terraform destroy
```

## Troubleshooting

### Check Connectivity

```bash
cd ../../configuration/ansible
ansible all -i inventory/terraform_inventory.yaml -m ping
```

### View Logs

```bash
# SSH to a management node
ssh ubuntu@<management-ip>

# View container logs
docker logs netbird-management
docker logs haproxy
docker logs pgbouncer
```

### Verify Inventory

```bash
cat ../../configuration/ansible/inventory/terraform_inventory.yaml
```

## File Structure

```
infrastructure/ansible-stack/
├── main.tf              # Provider and random resources
├── variables.tf         # Input variable definitions
├── terraform.tfvars     # Your configuration values
├── outputs.tf           # Output definitions
├── backend.tf           # Terraform backend configuration
├── versions.tf          # Provider version constraints
└── templates/
    └── inventory.yaml.tpl  # Ansible inventory template
```

## Related Documentation

### Configuration
- [Ansible Configuration Guide](../../configuration/ansible/README.md) - Detailed Ansible usage
- [Ansible Roles Documentation](../../configuration/ansible/README.md#roles) - Role descriptions

### Deployment
- [Deployment Runbook](../../docs/runbooks/ansible-stack/deployment.md) - Step-by-step deployment
- [Upgrade Runbook](../../docs/runbooks/ansible-stack/upgrade.md) - Upgrade procedures

### Operations
- [Operations Book](../../docs/operations-book/ansible-stack/README.md) - Operations guide
- [Troubleshooting](../../docs/runbooks/ansible-stack/troubleshooting-restoration.md) - Common issues

## Support

- [NetBird Documentation](https://docs.netbird.io/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
