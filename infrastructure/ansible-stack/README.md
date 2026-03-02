# NetBird Ansible Stack

Production-grade NetBird deployment using Terraform + Ansible + Docker Compose.

## Architecture

```
Internet → HAProxy → Management Cluster → PostgreSQL + PgBouncer
                  → Relay Servers
```

## Features

- High availability with automatic failover
- Automatic TLS certificates via ACME
- PgBouncer connection pooling
- Multi-node management cluster
- HAProxy load balancing with health checks

## Prerequisites

**Local Machine:**
- Terraform >= 1.6.0
- Ansible >= 2.10
- SSH key for server access

**Target Servers:**
- Ubuntu 20.04+ (Jammy or later)
- SSH key-based authentication
- Public + Private IP addresses
- Minimum: 2vCPU, 4GB RAM per management node

**External Services:**
- Keycloak (Identity Provider)
- PostgreSQL database (existing)
- DNS configured for your domain

## Quick Start

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify

```bash
curl -f https://your-domain.com/health
```

## Configuration

### Deployment Modes

**Manual (default):**
```hcl
auto_deploy = false  # Terraform generates inventory only
```

Run Ansible separately:
```bash
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

**Automatic:**
```hcl
auto_deploy = true  # Terraform runs Ansible automatically
```

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `netbird_domain` | Primary domain | `vpn.example.com` |
| `netbird_hosts` | Server definitions | See example |
| `database_type` | Database engine | `postgresql`, `sqlite` |
| `keycloak_url` | Keycloak URL | `https://auth.example.com` |
| `enable_haproxy_ha` | Enable HA failover | `true` |
| `enable_pgbouncer` | Enable connection pooling | `true` |

See `terraform.tfvars.example` for complete configuration.

## Operations

### Update Configuration

```bash
# Edit terraform.tfvars
terraform apply
```

### Redeploy Services

```bash
cd ../../configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

### Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Check Connectivity

```bash
cd ../../configuration/ansible
ansible all -i inventory/terraform_inventory.yaml -m ping
```

### View Container Logs

```bash
ssh ubuntu@<host-ip>
docker logs netbird-management
docker logs haproxy
docker logs pgbouncer
```

### Test Certificate

```bash
curl -v https://your-domain.com
```

### Check HAProxy Stats

```bash
# Access stats UI
http://your-domain.com:8404/stats
```

## High Availability

### Virtual IP Failover

```bash
# Check VIP assignment
ssh ubuntu@<proxy-ip>
ip addr show | grep <virtual-ip>

# Test failover
sudo systemctl stop keepalived
# VIP moves to backup node within 3-5 seconds
```

### Management Cluster

```bash
# Stop one management node
docker stop netbird-management

# Traffic automatically routes to other nodes
# HAProxy health checks detect failure within 5 seconds
```

## Security

- All communication TLS-encrypted
- Automatic certificate renewal
- UFW firewall on all nodes
- SSH key-based authentication only
- Database SSL connections required

## Monitoring

- HAProxy stats dashboard
- Docker container metrics
- System logs via journalctl
- Application logs via docker logs

## Documentation

- [NetBird Docs](https://docs.netbird.io/)
- [Terraform Docs](https://www.terraform.io/docs)
- [Ansible Docs](https://docs.ansible.com/)
- [HAProxy Docs](https://www.haproxy.org/)
