# Keycloak Deployment Automation for NetBird

Production-ready Ansible automation for deploying and configuring Keycloak Identity and Access Management system with Caddy reverse proxy, specifically optimized for NetBird integration.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Deployment Modes](#deployment-modes)
- [Quick Start](#quick-start)
- [Network Access Setup](#network-access-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [External Keycloak Mode](#external-keycloak-mode)
- [Troubleshooting](#troubleshooting)
- [NetBird Integration](#netbird-integration)

## Overview

This document details the Keycloak deployment automation for NetBird. For a high-level overview of the entire project, including the observability stack, refer to the main [README.md](../README.md).

This project provides automated deployment of:
- **Keycloak 22.0** - Identity and Access Management
- **PostgreSQL 15** - Keycloak database
- **Caddy 2** - Reverse proxy with automatic HTTPS

### Key Features

- **Automated Configuration**: Automatically creates and configures NetBird realm with appropriate clients and service accounts
- **Flexible SSL/TLS**: Automatic certificate management with self-signed certificates for development and Let's Encrypt for production
- **Edge Proxy Mode**: Properly configured for reverse proxy deployment with Caddy
- **IdP Integration**: Complete OIDC configuration with proper role assignments for NetBird management
- **Idempotent Operations**: Safe to run multiple times without causing configuration drift
- **Two Deployment Modes**: Support for both new Keycloak deployments and integration with existing instances

## Architecture

```
┌─────────────────────────────────────────┐
│  Caddy (Reverse Proxy)                  │
│  Ports: 80 (HTTP), 443 (HTTPS)          │
│  - Automatic HTTPS                       │
│  - TLS termination                       │
└──────────────┬──────────────────────────┘
               │ reverse_proxy
               ▼
┌─────────────────────────────────────────┐
│  Keycloak (netbird-keycloak)            │
│  Port: 8080 (internal)                  │
│  - Edge proxy mode                       │
│  - NetBird realm configured              │
└──────────────┬──────────────────────────┘
               │ connects to
               ▼
┌─────────────────────────────────────────┐
│  PostgreSQL (keycloak_postgres)         │
│  Port: 5432 (internal)                  │
│  - Persistent data storage               │
└─────────────────────────────────────────┘
```

All services run in Docker containers on a dedicated network.

## Deployment Modes

### 1. Deploy Mode (Default)
Deploys a complete new Keycloak instance with PostgreSQL and Caddy.

**Use when:**
- Setting up Keycloak from scratch
- You need full control over Keycloak
- Testing NetBird locally

### 2. External Mode
Connects to an existing Keycloak realm and configures clients for NetBird.

**Use when:**
- Keycloak is already deployed by someone else
- You have realm admin credentials
- Using a shared/corporate Keycloak instance

## Quick Start

### Prerequisites

- **Ansible** 2.9+ installed on your local machine
- **SSH access** to the target server
- **Ubuntu 22.04** on the target server
- **2GB RAM** minimum on target server

### 1. Configure Inventory

Edit `inventory.ini` with your server IP:

```ini
[keycloak]
10.165.218.128    # Replace with your server IP

[keycloak:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/ansible
```

### 2. Configure Variables

Edit `group_vars/keycloak.yml`:

```yaml
# Deployment mode
keycloak_deploy_mode: true
keycloak_external_mode: false

# Keycloak version
keycloak_version: "22.0"

# Domain configuration
keycloak_host: "10.165.218.128.nip.io"  # Use your server IP
keycloak_http_port: 8080

# Admin credentials (CHANGE THESE!)
keycloak_admin_user: "admin"
keycloak_admin_password: "TestAdmin123!"
keycloak_db_password: "TestDB123!"

# NetBird realm configuration
keycloak_realm: "netbird"
keycloak_client_netbird: "netbird-client"
keycloak_client_netbird_backend: "netbird-backend"
keycloak_valid_redirect_uris:
  - "https://10.165.218.128.nip.io/*"
  - "http://localhost:53000"
```

### 3. Test Connectivity

```bash
ansible -i inventory.ini keycloak -m ping
```

### 4. Deploy

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml
```

Deployment takes **2-5 minutes**.

## Network Access Setup

### For Multipass/Local VMs

Multipass VMs are on a private network. Choose one of these options:

#### Option A: Port Forwarding (Easiest for Testing)

Forward VM ports to your localhost:

```bash
./forward-ports.sh
```

Then access in browser:
- **HTTP**: http://localhost:8080
- **HTTPS**: https://localhost:8443 (accept self-signed cert)

Press `Ctrl+C` to stop forwarding.

#### Option B: Bridge Network (Production-like)

Make VM accessible on your LAN:

1. **Stop the VM:**
   ```bash
   multipass stop target
   ```

2. **Delete and recreate with bridge:**
   ```bash
   multipass delete target
   multipass purge
   multipass launch --name target --network name=en0,mode=manual  # macOS
   # or
   multipass launch --name target --network name=eth0,mode=manual  # Linux
   ```

3. **Configure static IP in VM:**
   ```bash
   multipass shell target
   sudo nano /etc/netplan/50-cloud-init.yaml
   ```

4. **Update inventory** with the new IP

5. **Redeploy**

### For Cloud/VPS Deployments

If deploying to a cloud server with a public IP:

1. **Update domain** in `group_vars/keycloak.yml`:
   ```yaml
   keycloak_host: "keycloak.yourdomain.com"
   ```

2. **Configure DNS** A record pointing to your server IP

3. **Open firewall** ports 80 and 443:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

4. **Deploy** - Caddy will automatically get Let's Encrypt certificates!

## Configuration

### SSL/TLS Certificates

Caddy automatically handles certificates:

- **`.nip.io` domains** → Self-signed certificates (local testing)
- **`localhost`** → Self-signed certificates
- **Real FQDNs** → Let's Encrypt certificates (free, trusted)

No manual certificate management needed!

### Security Best Practices

⚠️ **For Production:**

1. **Change default passwords:**
   ```yaml
   keycloak_admin_password: "{{ vault_keycloak_admin_password }}"
   keycloak_db_password: "{{ vault_keycloak_db_password }}"
   ```

2. **Use Ansible Vault:**
   ```bash
   ansible-vault encrypt group_vars/keycloak.yml
   ansible-playbook -i inventory.ini deploy_keycloak.yml --ask-vault-pass
   ```

3. **Enable firewall:**
   ```bash
   ansible -i inventory.ini keycloak -m command -a "ufw enable" --become
   ```

4. **Regular backups:**
   ```bash
   ssh ubuntu@yourserver "docker exec keycloak_postgres pg_dump -U keycloak keycloak > backup.sql"
   ```

## Deployment

### Fresh Deployment

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml
```

### Update Configuration Only

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml --tags configure
```

### Check Mode (Dry Run)

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml -v
```

## External Keycloak Mode

Use this when Keycloak is already deployed and you need to configure it for NetBird.

### Requirements

- Existing Keycloak instance
- Realm created
- Realm admin user credentials

### Configuration

Edit `group_vars/keycloak.yml`:

```yaml
# External mode
keycloak_deploy_mode: false
keycloak_external_mode: true

# OIDC endpoint (get from Keycloak admin)
keycloak_oidc_configuration_endpoint: "https://keycloak.example.com/realms/netbird/.well-known/openid-configuration"

# Realm admin credentials
keycloak_realm_admin_user: "realm-admin"
keycloak_realm_admin_password: "admin-password"

# Client names (will be created if they don't exist)
keycloak_client_netbird: "netbird-client"
keycloak_client_netbird_backend: "netbird-backend"

# SSL validation
keycloak_validate_certs: true  # Set to false for self-signed certs
```

### Deploy

```bash
ansible-playbook -i inventory.ini deploy_keycloak.yml
```

The playbook will:
1. ✅ Connect to the existing Keycloak
2. ✅ Check if clients exist (create if needed)
3. ✅ Configure service account with proper roles
4. ✅ Display NetBird configuration

## Troubleshooting

### Can't access Keycloak in browser

**Symptoms:** curl works but browser doesn't load

**Solution:**
- For Multipass VMs: Use `./forward-ports.sh`
- For cloud servers: Check firewall rules

### SSL Certificate Warnings

**For `.nip.io` domains:**
- Expected! Click "Advanced" → "Accept Risk"
- Caddy uses self-signed certs for local domains

**For real domains:**
- Wait 30 seconds for Let's Encrypt
- Check DNS is pointing to your server
- Ensure ports 80/443 are open

### Keycloak unhealthy

Check logs:
```bash
ssh ubuntu@yourserver "docker logs netbird-keycloak"
```

Common issues:
- Database not ready → Wait 30 seconds
- Memory issues → Ensure 2GB+ RAM
- Port conflicts → Check `docker ps`

### Caddy not proxying

Check Caddy logs:
```bash
ssh ubuntu@yourserver "docker logs caddy"
```

Restart Caddy:
```bash
ssh ubuntu@yourserver "cd /opt/keycloak && docker compose restart caddy"
```

### Clean slate (DESTROYS DATA)

```bash
ssh ubuntu@yourserver "cd /opt/keycloak && docker compose down -v && rm -rf /opt/keycloak"
ansible-playbook -i inventory.ini deploy_keycloak.yml
```

## NetBird Integration

After deployment, you'll see:

```
==========================================
Keycloak Realm Configuration Complete
==========================================
Realm: netbird
Host: https://10.165.218.128.nip.io

OIDC Configuration:
  Endpoint: https://10.165.218.128.nip.io/realms/netbird/.well-known/openid-configuration
  
Frontend Client (Public):
  Client ID: netbird-client
  
Backend Client (Service Account):
  Client ID: netbird-backend
  Secret: <SAVED_TO_FILE>

Configuration saved to: /opt/keycloak/netbird-config.env
==========================================
```

### Get NetBird Configuration

```bash
ssh ubuntu@yourserver "cat /opt/keycloak/netbird-config.env"
```

### Add to NetBird `setup.env`

```bash
# Authentication
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://10.165.218.128.nip.io/realms/netbird/.well-known/openid-configuration
NETBIRD_USE_AUTH0=false
NETBIRD_AUTH_CLIENT_ID=netbird-client
NETBIRD_AUTH_SUPPORTED_SCOPES="openid profile email offline_access api"
NETBIRD_AUTH_AUDIENCE=netbird-client
NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID=netbird-client
NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE=netbird-client

# Management
NETBIRD_MGMT_IDP=keycloak
NETBIRD_IDP_MGMT_CLIENT_ID=netbird-backend
NETBIRD_IDP_MGMT_CLIENT_SECRET=<YOUR_SECRET_FROM_FILE>
NETBIRD_IDP_MGMT_EXTRA_ADMIN_ENDPOINT=https://10.165.218.128.nip.io/admin/realms/netbird
```

### Access Keycloak Admin

URL: https://10.165.218.128.nip.io/admin  
Username: `admin`  
Password: (from `group_vars/keycloak.yml`)

## Files Structure

```
deploy/
├── inventory.ini              # Target servers
├── deploy_keycloak.yml        # Main playbook
├── group_vars/
│   └── keycloak.yml          # Configuration variables
├── roles/
│   └── keycloak/
│       ├── tasks/
│       │   ├── main.yml                          # Entry point
│       │   ├── deploy.yml                        # Deploy new Keycloak
│       │   ├── configure_realm.yml               # Configure realm/clients
│       │   └── validate_external.yml             # External mode
│       ├── templates/
│       │   ├── keycloak-compose.yml.j2           # Docker Compose
│       │   ├── Caddyfile.j2                      # Caddy config
│       │   ├── realm-import.json.j2              # Realm template
│       │   └── realm-config.env.j2               # NetBird config
│       ├── defaults/
│       │   └── main.yml                          # Default variables
│       └── handlers/
│           └── main.yml                          # Service handlers
├── forward-ports.sh           # Port forwarding helper
└── README.md                 # This file
```

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review Ansible verbose output: `ansible-playbook ... -vvv`
3. Check service logs: `docker logs <container_name>`
4. Review NetBird documentation: https://docs.netbird.io

## License

This automation follows the same license as the NetBird project.
