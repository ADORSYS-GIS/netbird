# NetBird with Caddy Deployment Automation

Complete automation for deploying NetBird with Caddy reverse proxy and Keycloak OpenID Connect authentication. **All methods automatically configure Keycloak realm and OAuth clients.**

## Quick Overview

Three deployment methods, all with automated Keycloak setup:

| Method | Best For | Time | Commands |
|--------|----------|------|----------|
| **QuickStart (Local Docker)** | Testing/Development | 5 min | `ansible-playbook -i inventory.yaml playbook.yaml --ask-vault-pass` |
| **Remote SSH** | Single Server | 15 min | `ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --ask-vault-pass` |
| **GitHub Actions** | CI/CD & Auto Deploy | 10 min | Push to main branch (auto-triggers) |

## Prerequisites

- **Keycloak instance** (deployed separately, accessible from internet)
- **Keycloak admin credentials** (username & password)
- **Registered domain name** (pointing to server IP)
- **Email address** (for Let's Encrypt certificates)

### Additional for Local/SSH:
- Ansible installed
- Docker & Docker Compose v2
- **External Docker Network:** Create the network that Keycloak and NetBird will share.
  ```bash
  docker network create key-netbird
  ```

### Additional for Remote SSH:
- SSH access to target server with `sudo` privileges
- Ubuntu 20.04+ or Debian 11+ server

### Additional for GitHub Actions:
- GitHub repository with write access to repository secrets

##  Features

 **Fully Automated Keycloak Setup** - Realm & OAuth clients created automatically  
 **Three Deployment Methods** - Local, SSH, or GitHub Actions pipeline  
 **Secure Secrets** - Ansible Vault encryption for all sensitive data  
 **Dynamic Configuration** - Jinja2 templating for all config files  
 **Automatic TLS** - Let's Encrypt via Caddy, auto-renewal included  
 **Complete NAT Traversal** - STUN/TURN via Coturn for all network types  
 **Production Ready** - Idempotent, repeatable, offline-capable  

##  Directory Structure

```
infrastructure/ansible/
 playbook.yaml                    # Main Ansible playbook
 inventory.yaml                   # Host configuration
 ansible.cfg                      # Ansible settings
 group_vars/netbird_servers/
    vars.yml                    # Non-secret variables
    vault.yml                   # Encrypted secrets
 templates/
    Caddyfile.j2               # Reverse proxy
    docker-compose.yml.j2       # Services
    management.json.j2          # Management config
    turnserver.conf.j2          # TURN/STUN config
 README.md                        # This file
```

---

#  QuickStart: Local Docker Deployment

This guide will walk you through deploying a full NetBird stack on your local machine for testing and development.

## Step 1: Clone Repository

```bash
git clone https://github.com/netbirdio/netbird.git
cd netbird/infrastructure/ansible
```

## Step 2: Configure Variables

### Get Your Values

Before configuring, gather these values:

```bash
# Get your server's public IP
curl -s https://api.ipify.org

# Keycloak details (from your existing Keycloak instance)
KEYCLOAK_DOMAIN="idp.example.com"          # Your Keycloak domain
KEYCLOAK_PORT="8080"                       # Keycloak port (usually 8080)
KEYCLOAK_ADMIN_USER="admin"                # Keycloak admin username
KEYCLOAK_ADMIN_PASSWORD="your-password"    # Keycloak admin password
KEYCLOAK_REALM="netbird"                   # Realm to create

# NetBird configuration
NETBIRD_DOMAIN="netbird.example.com"       # Your NetBird domain
NETBIRD_EMAIL="admin@example.com"          # For Let's Encrypt
SERVER_PUBLIC_IP="1.2.3.4"                 # From curl command above
```

### Set Variables in vars.yml

Edit `group_vars/netbird_servers/vars.yml`:

```yaml
---
# NetBird Domain and Email
netbird_domain: "netbird.example.com"
netbird_caddy_email: "admin@example.com"
netbird_external_ip: "1.2.3.4"

# Keycloak Configuration for Auto-Setup
keycloak_domain: "idp.example.com"
keycloak_port: "8080"
keycloak_admin_user: "admin"
keycloak_admin_password: "{{ vault_keycloak_admin_password }}"
keycloak_auth_url: "https://idp.example.com"

# NetBird Realm and IdP Settings
netbird_realm: "netbird"
idp_service_name: "keycloak"

# Keycloak Auto-Setup Flag (set to false to skip Keycloak configuration)
keycloak_auto_setup: true
```

**Required Variables Checklist:**
-  `netbird_domain` - Your NetBird instance domain
-  `netbird_caddy_email` - Email for Let's Encrypt certificates
-  `netbird_external_ip` - Server public IP address
-  `keycloak_domain` - Your Keycloak server domain
-  `keycloak_port` - Keycloak port (default: 8080)
-  `keycloak_admin_user` - Keycloak admin username
-  `keycloak_admin_password` - (from vault) Keycloak admin password
-  `netbird_realm` - Realm name to create in Keycloak

## Step 3: Generate & Encrypt Secrets

```bash
./encrypt-vault.sh
```

This script will:
- Prompt for secrets or auto-generate them
- Create encrypted `group_vars/netbird_servers/vault.yml`
- Save vault password to `.vault_pass` (already in .gitignore)

## Step 4: Configure Inventory for Local Deployment

Edit `inventory.yaml` to target your local machine:

```yaml
all:
  children:
    netbird_servers:
      hosts:
        netbird-primary:
          ansible_host: localhost
          ansible_connection: local
```

## Step 5: Run Deployment

Execute the Ansible playbook. Enter the vault password when prompted.

```bash
ansible-playbook -i inventory.yaml playbook.yaml --ask-vault-pass
```

## Step 6: Access & Verify

### Access NetBird
Once the deployment is complete, access the NetBird dashboard at:
```
http://localhost:53000
```
You can then log in with your Keycloak credentials.

### Verify Services
To confirm that all services are running, use the following command:
```bash
docker compose -f /opt/netbird/docker-compose.yml ps
```

---

#  Variable Reference Guide

## vars.yml - Non-Sensitive Configuration

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `netbird_domain` |  Yes | Your NetBird instance domain | `netbird.example.com` |
| `netbird_caddy_email` |  Yes | Email for Let's Encrypt | `admin@example.com` |
| `netbird_external_ip` |  Yes | Server public IP address | `1.2.3.4` |
| `keycloak_domain` |  Yes | Your Keycloak server domain | `idp.example.com` |
| `keycloak_port` |  Yes | Keycloak port | `8080` |
| `idp_service_name` |  Yes | Internal IdP service name | `keycloak` |
| `netbird_realm` |  Yes | Realm name to create | `netbird` |

## vault.yml - Encrypted Secrets

These are automatically generated but can be overridden:

| Variable | Required | Description |
|----------|----------|-------------|
| `vault_keycloak_admin_password` |  Yes | Keycloak admin password (for auto-realm setup) |
| `vault_netbird_auth_client_id` |  Yes | Keycloak client ID for web (auto-generated) |
| `vault_netbird_idp_mgmt_client_id` |  Yes | Keycloak client ID for management API (auto-generated) |
| `vault_netbird_idp_mgmt_client_secret` |  Yes | Keycloak client secret for management (auto-generated) |
| `vault_netbird_management_secret` |  Yes | Management service secret (32+ chars) |
| `vault_netbird_relay_secret` |  Yes | Relay service secret (32+ chars) |
| `vault_netbird_turn_secret` |  Yes | TURN service secret (32+ chars) |
| `vault_netbird_turn_password` |  Yes | TURN password (24+ chars) |
| `vault_netbird_datastore_encryption_key` |  Yes | Database encryption key (32+ chars) |

## Generate Random Secrets

Use these commands to generate secure random values:

```bash
# Generate 32-character secret (for management, relay, datastore)
openssl rand -base64 32

# Generate 24-character password (for TURN)
openssl rand -base64 24

# Generate multiple at once
echo "Management: $(openssl rand -base64 32)"
echo "Relay: $(openssl rand -base64 32)"
echo "TURN Secret: $(openssl rand -base64 32)"
echo "TURN Password: $(openssl rand -base64 24)"
echo "Datastore Key: $(openssl rand -base64 32)"
```

## Environment Variables During Deployment

These are automatically passed to Docker Compose:

```
NETBIRD_DOMAIN
NETBIRD_CADDY_EMAIL
NETBIRD_AUTH_AUDIENCE
NETBIRD_AUTH_CLIENT_ID
NETBIRD_AUTH_AUTHORITY
NETBIRD_MANAGEMENT_SECRET
NETBIRD_RELAY_SECRET
NETBIRD_TURN_SECRET
NETBIRD_TURN_PASSWORD
NETBIRD_DATASTORE_ENCRYPTION_KEY
```

---

#  Deployment Method 2: Remote SSH Server

**Best for:** Single server production deployments with full automation

### Step 1: Configure SSH Access

Edit `inventory.yaml`:

```yaml
all:
  children:
    netbird_servers:
      hosts:
        netbird-primary:
          ansible_host: YOUR_SERVER_IP          # or domain
          ansible_user: ubuntu
          ansible_ssh_private_key_file: /path/to/ssh/key
          ansible_connection: ssh
```

### Step 2: Deploy with Automated Keycloak

The playbook will automatically:
1. Connect to your Keycloak instance
2. Create the NetBird realm (if not exists)
3. Configure OAuth clients
4. Generate all required secrets
5. Deploy all services

```bash
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --ask-vault-pass
```

The `--ask-become-pass` flag prompts for `sudo` password on target server.

### Step 3: Verify Deployment

```bash
# SSH into the server
ssh -i /path/to/ssh/key ubuntu@YOUR_SERVER_IP

# Check services
cd /opt/netbird
docker compose ps

# View logs
docker compose logs -f management
```

### Step 4: Access NetBird

```
https://your-domain.com
```

Login with Keycloak credentials.

---

#  Deployment Method 3: GitHub Actions Pipeline

**Best for:** CI/CD, automated deployments, multiple environments

The workflow at `.github/workflows/ansible-deploy.yml` handles everything automatically.

### Step 1: Configure GitHub Secrets

Go to **Settings > Secrets and variables > Actions** and add:

**Core Configuration:**
```
NETBIRD_DOMAIN: netbird.example.com
NETBIRD_CADDY_EMAIL: admin@example.com
```

**Keycloak Configuration (for automatic setup):**
```
KEYCLOAK_URL: https://idp.example.com
KEYCLOAK_ADMIN_USER: admin
KEYCLOAK_ADMIN_PASSWORD: your-keycloak-password
NETBIRD_REALM: netbird (optional, default: netbird)
IDP_SERVICE_NAME: keycloak (optional, default: keycloak)
KEYCLOAK_PORT: 8080 (optional, default: 8080)
```

**Choose ONE deployment target:**

**Option A: Deploy to Remote Server via SSH**
```
ANSIBLE_SSH_KEY: (your private SSH key)
ANSIBLE_HOST: your-server-ip-or-domain
ANSIBLE_USER: ubuntu (optional, default: ubuntu)
```

**Option B: Deploy to AWS EC2 via SSM**
```
AWS_ACCESS_KEY_ID: your-aws-key
AWS_SECRET_ACCESS_KEY: your-aws-secret
AWS_REGION: us-east-1
AWS_INSTANCE_ID: i-0123456789abcdef0
```

### Step 2: Trigger Deployment

**Automatic Trigger:**
- Push changes to `main` branch in `infrastructure/ansible/` directory
- Workflow automatically starts

**Manual Trigger:**
1. Go to **Actions** tab
2. Select **Ansible Deployment**
3. Click **Run workflow**
4. Choose deployment target (ssh_remote or aws_ssm)
5. (Optional) Override host/user for SSH

### Step 3: Monitor Workflow

- Check **Actions** tab for workflow status
- View logs for deployment details
- Workflow automatically creates realm and configures Keycloak

### Step 4: Access Your NetBird Instance

```
https://your-netbird-domain.com
```

---

#  Managing Ansible Vault

### View Encrypted Secrets

```bash
ansible-vault view group_vars/netbird_servers/vault.yml
```

### Edit Encrypted Secrets

```bash
ansible-vault edit group_vars/netbird_servers/vault.yml
```

### Change Vault Password

```bash
ansible-vault rekey group_vars/netbird_servers/vault.yml
```

### For GitHub Actions

If using GitHub Actions, add vault password to secrets:

1. **Settings > Secrets and variables > Actions**
2. **New repository secret**
3. Name: `ANSIBLE_VAULT_PASSWORD`
4. Value: Your vault password

Workflow automatically uses this to decrypt vault.

---

#  Services Deployed

| Service | Purpose | Port | Container |
|---------|---------|------|-----------|
| **Management** | API & peer management | 443 (Caddy) | `netbird/management` |
| **Signal** | WebRTC signaling | 443 (Caddy) | `netbird/signal` |
| **Relay** | DERP relay for NAT | 443 (Caddy) | `netbird/relay` |
| **TURN/STUN** | NAT traversal | 3478/UDP | `coturn/coturn` |
| **Caddy** | Reverse proxy + TLS | 80, 443 | `caddy:latest` |
| **Dashboard** | Web UI | 443 (Caddy) | `netbird/dashboard` |

---

#  Verification Checklist

### For Local/SSH Deployments

```bash
# SSH into server (skip for local)
ssh -i key.pem ubuntu@your-server

# Check containers
cd /opt/netbird
docker compose ps

# Verify HTTPS
curl https://your-domain/api/health

# Check logs
docker compose logs management
docker compose logs signal
docker compose logs relay
docker compose logs coturn
docker compose logs caddy
```

### For GitHub Actions

- Check **Actions** tab for green checkmark
- Verify services running on target server
- Access dashboard at your domain
- Check management logs for errors

---

#  Troubleshooting

| Issue | Solution |
|-------|----------|
| Services not starting | Check Docker: `docker --version` |
| Certificate errors | Verify DNS points to server IP, ports 80/443 open |
| Cannot reach Keycloak | Check `keycloak_domain` is accessible, credentials correct |
| TURN not working | Ensure UDP ports 3478, 49152-65535 open in firewall |
| Vault decrypt fails | Verify vault password is correct |
| Ansible connection timeout | Check SSH key permissions: `chmod 600 /path/to/key` |
| Keycloak auth fails | Verify Keycloak URL doesn't have trailing slash |

---

#  Security Best Practices

- **Ansible Vault**: All secrets encrypted. Never commit `.vault_pass`
- **GitHub Secrets**: Store sensitive values only in GitHub, not in repo
- **SSH Keys**: Use strong keys, `chmod 600`, never commit them
- **Keycloak**: Use strong admin password, restrict access
- **Firewall**: Only open necessary ports (80, 443, 3478/UDP)
- **TLS**: Always use HTTPS in production (Caddy auto-handles)
- **Updates**: Keep images updated regularly via Docker pulls

---

#  Configuration Files

### vars.yml (Non-Sensitive)

Contains public configuration:
- Domain names
- Port numbers
- Service names
- Keycloak settings

### vault.yml (Encrypted Secrets)

Contains sensitive data (encrypted):
- Service secrets
- Database encryption keys
- Keycloak client secrets
- TURN passwords

Encrypted using Ansible Vault. Password stored in `.vault_pass` or GitHub Secrets.

### Keycloak Auto-Configuration

Both local/SSH and GitHub Actions automatically:
1. Connect to Keycloak admin API
2. Create NetBird realm
3. Configure OAuth clients
4. Generate service secrets
5. Return configuration for Ansible

---

#  Advanced Usage

### Pre-configured Vault (Skip Keycloak Auto-Setup)

If you have a pre-encrypted vault:

1. Copy vault files to `group_vars/netbird_servers/`
2. Set `ANSIBLE_VAULT_PASSWORD` (local) or GitHub secret
3. Deploy normally - vault values will be used

### Custom Keycloak Realm

Change realm name in GitHub Actions:
- Set secret `NETBIRD_REALM: your-realm-name`

### Override Secrets

For GitHub Actions, override vault values with secrets:
- `NETBIRD_MANAGEMENT_SECRET`
- `NETBIRD_RELAY_SECRET`
- `NETBIRD_TURN_SECRET`
- `NETBIRD_TURN_PASSWORD`
- `NETBIRD_DATASTORE_ENCRYPTION_KEY`

Extra-vars override vault values when provided.

### AWS SSM Instead of SSH

For EC2 instances without SSH port open:
- Use `aws_ssm` deployment target in GitHub Actions
- Requires AWS IAM permissions for SSM
- More secure (no open port 22)

---

#  Additional Resources

- [NetBird Documentation](https://docs.netbird.io)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Ansible Documentation](https://docs.ansible.com/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose](https://docs.docker.com/compose/)

---

#  Support

For issues:
1. Check **Troubleshooting** section above
2. Review service logs: `docker compose logs -f [service-name]`
3. Check **Keycloak** realm configuration
4. Verify DNS and firewall settings
5. Consult [NetBird Docs](https://docs.netbird.io)