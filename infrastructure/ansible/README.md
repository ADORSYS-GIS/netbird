# NetBird with Caddy Deployment Automation

Complete automation for deploying NetBird with Caddy reverse proxy and Keycloak OpenID Connect authentication. **All methods automatically configure Keycloak realm and OAuth clients.**

##  Features

- **Fully Automated Keycloak Setup** - Realm, OAuth clients, and default admin user created automatically
- **Three Deployment Methods** - Local, SSH, or GitHub Actions pipeline
- **Cleanup & Teardown** - Complete removal of deployment and Keycloak resources with a single command
- **Dynamic Configuration** - Jinja2 templating for all config files
- **Automatic TLS** - Let's Encrypt via Caddy, auto-renewal included
- **Complete NAT Traversal** - STUN/TURN via Coturn for all network types
- **Production Ready** - Idempotent, repeatable, offline-capable

## Quick Overview

Three deployment methods, all with automated Keycloak setup:

| Method | Best For | Time | Commands |
|--------|----------|------|----------|
| **QuickStart (Local Docker)** | Testing/Development | 5 min | `ansible-playbook -i inventory.yaml playbook.yaml` |
| **Remote SSH** | Single Server | 15 min | `ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass` |
| **GitHub Actions** | CI/CD & Auto Deploy | 10 min | Push to main branch (auto-triggers) |
| **Cleanup** | Environment Reset | 2 min | `ansible-playbook -i inventory.yaml playbook.yaml --tags cleanup` |

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
    vars.yml                    # Variables & Placeholders
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

Edit `group_vars/netbird_servers/vars.yml` and fill in the placeholders.

**Required Variables Checklist:**
-  `netbird_domain` - Your NetBird instance domain
-  `netbird_caddy_email` - Email for Let's Encrypt certificates
-  `netbird_external_ip` - Server public IP address
-  `keycloak_domain` - Your Keycloak server domain
-  `keycloak_port` - Keycloak port (default: 8080)
-  `keycloak_admin_user` - Keycloak admin username
-  `keycloak_admin_password` - Keycloak admin password
-  `netbird_realm` - Realm name to create in Keycloak

## Step 3: Configure Inventory for Local Deployment

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

## Step 4: Run Deployment

Execute the Ansible playbook.

```bash
ansible-playbook -i inventory.yaml playbook.yaml
```

## Step 5: Access & Verify

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

#  Cleanup & Teardown

If you need to completely remove the NetBird deployment and reset your environment, you can use the cleanup routine.

## Local/SSH Cleanup

Run the playbook with the `cleanup` tag:

```bash
ansible-playbook -i inventory.yaml playbook.yaml --tags cleanup \
  -e "keycloak_admin_password=your-password"
```

**What this does:**
1. Deletes the NetBird realm from your Keycloak instance
2. Stops and removes all Docker containers
3. Deletes the `/opt/netbird` deployment directory
4. Removes the `key-netbird` Docker network

## GitHub Actions Cleanup

1. Go to the **Actions** tab in your GitHub repository.
2. Select the **Ansible Deployment** workflow.
3. Click **Run workflow**.
4. Select **cleanup** in the "Action to perform" dropdown.
5. Click **Run workflow**.

OR, Locally:

``` # Replace <BRANCH_NAME> with your feature branch name                        
gh workflow run "Ansible Deployment" \
  --ref <BRANCH_NAME> \
  -f action=cleanup \
  -f deployment_target=<TARGET_OPTION> # ssh_remote/aws_ssm
```

```bash
ansible-playbook -i inventory.yaml playbook.

---

#  Variable Reference Guide

## vars.yml - Configuration

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `netbird_domain` |  Yes | Your NetBird instance domain | `netbird.example.com` |
| `netbird_caddy_email` |  Yes | Email for Let's Encrypt | `admin@example.com` |
| `netbird_external_ip` |  Yes | Server public IP address | `1.2.3.4` |
| `keycloak_domain` |  Yes | Your Keycloak server domain | `idp.example.com` |
| `keycloak_port` |  Yes | Keycloak port | `8080` |
| `keycloak_admin_password` |  Yes | Keycloak admin password | `admin-pass` |
| `idp_service_name` |  Yes | Internal IdP service name | `keycloak` |
| `netbird_realm` |  Yes | Realm name to create | `netbird` |
| `netbird_management_secret` |  Yes | Management service secret (32+ chars) | `openssl rand -base64 32` |
| `netbird_relay_secret` |  Yes | Relay service secret (32+ chars) | `openssl rand -base64 32` |
| `netbird_turn_secret` |  Yes | TURN service secret (32+ chars) | `openssl rand -base64 32` |
| `netbird_turn_password` |  Yes | TURN password (24+ chars) | `openssl rand -base64 24` |
| `netbird_datastore_encryption_key` |  Yes | Database encryption key (32+ chars) | `openssl rand -base64 32` |

## Generate Random Secrets

Use these commands to generate secure random values:

```bash
# Generate 32-character secret (for management, relay, datastore)
openssl rand -base64 32

# Generate 24-character password (for TURN)
openssl rand -base64 24
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

```bash
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass
```

---

#  Deployment Method 3: GitHub Actions Pipeline

**Best for:** CI/CD, automated deployments, multiple environments

The workflow at `.github/workflows/ansible-deploy.yml` handles everything automatically.

### Step 1: Configure GitHub Secrets

Go to **Settings > Secrets and variables > Actions** and add:

**Core Configuration:**
```
NETBIRD_DOMAIN: <YOUR_NETBIRD_DOMAIN>
NETBIRD_CADDY_EMAIL: <YOUR_NETBIRD_CADDY_EMAIL>
NETBIRD_DEFAULT_USER: <YOUR_NETBIRD_DEFAULT_USER>
NETBIRD_DEFAULT_PASSWORD: <YOUR_NETBIRD_DEFAULT_PASSWORD>
NETBIRD_REALM: <YOUR_NETBIRD_REALM_NAME>
```

**Keycloak Configuration (for automatic setup):**
```
KEYCLOAK_URL: <YOUR_KEYCLOAK_URL>
KEYCLOAK_ADMIN_USER: <YOUR_KEYCLOAK_ADMIN_USER>
KEYCLOAK_ADMIN_PASSWORD: <YOUR_KEYCLOAK_ADMIN_PASSWORD>
```

### Step
```

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

#  Security Best Practices

- **GitHub Secrets**: Store sensitive values only in GitHub, not in repo
- **SSH Keys**: Use strong keys, `chmod 600`, never commit them
- **Keycloak**: Use strong admin password, restrict access
- **Firewall**: Only open necessary ports (80, 443, 3478/UDP)
- **TLS**: Always use HTTPS in production (Caddy auto-handles)
- **Updates**: Keep images updated regularly via Docker pulls
