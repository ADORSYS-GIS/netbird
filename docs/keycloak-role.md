# Keycloak Ansible Role

## Overview

Deploys and configures Keycloak as an identity provider.

**Two Modes:**
1. Deploy Mode - New Keycloak instance
2. External Mode - Existing Keycloak instance

## Prerequisites

- Ansible 2.12+
- Docker & Docker Compose on target
- Reverse proxy (Caddy) for HTTPS
- Domain name

## Quick Setup

### 1. Configure Variables

Edit `deploy/group_vars/keycloak.yml`:

```yaml
keycloak_deploy_mode: true
keycloak_external_mode: false
keycloak_host: "<KEYCLOAK_DOMAIN>" # Replace with your Keycloak domain (e.g., auth.yourdomain.com)
keycloak_admin_password: "{{ vault_keycloak_admin_password }}" # Use Ansible Vault for this
keycloak_db_password: "{{ vault_keycloak_db_password }}" # Use Ansible Vault for this
```

### 2. Run Playbook

```bash
ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml
```

### 3. Setup Caddy

```
<KEYCLOAK_DOMAIN> { # Replace with your Keycloak domain
    reverse_proxy localhost:8080 {
        header_up Host {host}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

## Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `keycloak_deploy_mode` | false | Deploy new instance |
| `keycloak_external_mode` | false | Use external instance |
| `keycloak_host` | `<KEYCLOAK_DOMAIN>` | Domain name for Keycloak |
| `keycloak_http_port` | 8080 | Internal HTTP port |
| `keycloak_admin_user` | admin | Admin username |
| `keycloak_realm` | netbird | Realm name |
| `keycloak_data_dir` | /opt/keycloak | Data directory |

## What It Does

**Deploy Mode:**
- Deploys PostgreSQL + Keycloak containers
- Creates configured realm
- Sets up two OIDC clients (public + service account)
- Assigns admin permissions
- Saves credentials to file

**External Mode:**
- Validates OIDC endpoint
- Tests credentials
- Exports facts for integration

## Output

Configuration saved to: `/opt/keycloak/<REALM_NAME>-config.env`

Contains:
- OIDC endpoints
- Client IDs and secrets
- Admin API endpoints

## Troubleshooting

**Keycloak won't start:**
```bash
docker logs keycloak
docker ps
```

**Can't access console:**
- Check reverse proxy: `systemctl status caddy`
- Verify DNS resolution
- Check firewall rules

**OIDC 404:**
- Wait for realm creation
- Verify realm name
- Check Keycloak logs

## Security

- Use Ansible Vault for passwords
- Keep Keycloak updated
- Use valid SSL certificates
- Restrict network access

## Integration

Role exports these facts:
- `netbird_oidc_configuration_endpoint`: The OIDC configuration endpoint for NetBird.
- `netbird_client_id`: The client ID for the NetBird frontend.
- `netbird_mgmt_client_id`: The client ID for the NetBird management backend.
- `netbird_mgmt_client_secret`: The client secret for the NetBird management backend.
