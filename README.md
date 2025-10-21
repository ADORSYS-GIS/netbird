# NetBird Keycloak Deployment

Ansible automation for deploying Keycloak as an identity provider.

## Quick Start

1. Update inventory: `deploy/inventory.ini`
2. Configure variables: `deploy/group_vars/keycloak.yml`
3. Run: `ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml`

## Project Structure

```
├── deploy/
│   ├── roles/keycloak/         # Keycloak Ansible role
│   ├── group_vars/             # Variable configuration
│   ├── inventory.ini           # Target hosts
│   └── deploy_keycloak.yml     # Main playbook
└── docs/                       # Documentation
```

## Features

- Automated Keycloak deployment with PostgreSQL
- Realm and client configuration
- Reverse proxy ready (Caddy)
- External Keycloak support
- Secure credential management

## Documentation

See [docs/keycloak-role.md](docs/keycloak-role.md) for complete documentation.
