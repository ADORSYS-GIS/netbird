# NetBird Infrastructure Automation

Production-grade Terraform + Ansible framework for deploying NetBird on existing VMs across AWS, GCP, Azure, or on-premises environments.

## Features

- **Multi-Cloud Discovery**: Automatically discovers existing VMs via tags/labels
- **Database Flexibility**: SQLite, PostgreSQL, or MySQL support
- **Security First**: Private IP binding, UFW firewall, defense-in-depth architecture
- **Automated Identity**: Terraform configures Keycloak realms and clients
- **Hybrid Ready**: Supports AWS, GCP, Azure, and manual/on-premises hosts

## Getting Started

See the [Getting Started Guide](infrastructure/ansible-stack/docs/getting-started.md) for complete deployment instructions. Deployment requires careful configuration of cloud discovery, database selection, and security settings.

## Documentation

### Deployment
- [Getting Started](infrastructure/ansible-stack/docs/getting-started.md) - Complete deployment guide
- [Configuration Reference](infrastructure/ansible-stack/docs/configuration-reference.md) - All variables and options
- [Troubleshooting](infrastructure/ansible-stack/docs/troubleshooting.md) - Common issues and solutions

### Architecture & Operations
- [Architecture](docs/architecture.md) - System design and components
- [Security Hardening](docs/operations/security-hardening.md) - Security best practices
- [Monitoring & Alerting](docs/operations/monitoring-alerting.md) - Observability setup
- [Disaster Recovery](docs/operations/disaster-recovery.md) - Backup and restore procedures

### Maintenance
- [Upgrade Guide](infrastructure/ansible-stack/docs/upgrade-guide.md) - Version upgrades
- [Database Migration](infrastructure/ansible-stack/docs/database-migration.md) - Switching database backends

## Security Architecture

This project implements defense-in-depth security:

- Cloud security groups block unnecessary traffic
- Host firewalls (UFW) allow only specific internal IPs
- Services bind strictly to private IPs
- Automatic HTTPS via Let's Encrypt/Caddy

See [Security Hardening](docs/operations/security-hardening.md) for details.

## Requirements

- Terraform >= 1.0
- Ansible >= 2.10
- Existing VMs with SSH access
- Cloud provider CLI (AWS/GCP/Azure) or manual host list
- Domain name for HTTPS
- Keycloak or Zitadel instance for SSO

## Acknowledgments

Built with [NetBird](https://netbird.io) - Open-source VPN management platform.
