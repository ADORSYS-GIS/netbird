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
- **jq & curl:** Required for automated Keycloak configuration.
  ```bash
  sudo apt install jq curl # Debian/Ubuntu
  brew install jq curl    # macOS
  ```
- **External Docker Network:** Create the network that Keycloak and NetBird will share.
  ```bash
  docker network create key-netbird
  ```

### Additional for Remote SSH:
- SSH access to target server with `sudo` privileges
- Ubuntu 20.04+ or Debian 11+ server

### Additional for GitHub Actions:
- GitHub repository with write access to repository secrets

##  GitHub Actions Pipeline Details

The CI/CD pipeline at `.github/workflows/ansible-deploy.yml` is the recommended way to manage your infrastructure.

### Manual Trigger (Workflow Dispatch)
You can manually trigger the deployment or cleanup from the GitHub Actions UI with the following inputs:
- **Action**: `deploy` (default) or `cleanup`.
- **Target**: `ssh_remote` (default) or `aws_ssm`.
- **NetBird Domain**: (Optional) Override the domain.
- **Keycloak URL**: (Optional) Override the IdP URL.
- **Admin Password**: (Optional) Set the dashboard admin password.

### Repository Secrets
For fully automated runs, configure these secrets in your repository:
- `NETBIRD_DOMAIN`: Your NetBird domain.
- `NETBIRD_CADDY_EMAIL`: Email for ACME.
- `KEYCLOAK_URL_SECRET`: Your Keycloak URL.
- `KEYCLOAK_ADMIN_USER_SECRET`: Keycloak API admin username.
- `KEYCLOAK_ADMIN_PASSWORD_SECRET`: Keycloak API admin password.
- `TARGET_HOST`: IP or Instance ID for deployment.
- `TARGET_USER`: SSH user (for `ssh_remote`).
- `SSH_PRIVATE_KEY`: Private key for authentication (for `ssh_remote`).
- `AWS_ACCESS_KEY_ID`: AWS access key for `aws_ssm`.
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for `aws_ssm`.
- `AWS_REGION`: AWS region for `aws_ssm`.
- `AWS_INSTANCE_ID`: Target EC2 Instance ID for `aws_ssm`.
- `AWS_S3_BUCKET`: **Required for `aws_ssm`**. Private S3 bucket used for staging file transfers via Session Manager.

### AWS SSM Requirements
When using `deployment_target: aws_ssm`, the following are required:
1. **S3 Bucket**: A private S3 bucket in the same region as your instance.
2. **IAM Permissions**: 
   - The GitHub Runner needs `s3:PutObject` and `s3:GetObject` on the bucket.
   - The Target EC2 instance needs an Instance Profile with `s3:GetObject` and `s3:PutObject` permissions.
3. **Session Manager Plugin**: Automatically installed by the GitHub Action workflow.

### Repository Variables
You can set default behaviors using GitHub Variables:
- `DEPLOY_ACTION`: Default to `deploy` or `cleanup`.
- `DEPLOY_TARGET`: Default to `ssh_remote` or `aws_ssm`.

### Full Secret Reference (GitHub Secrets)

For advanced users who want to provide their own keys instead of using auto-generation:

| Secret Name | Description |
|-------------|-------------|
| `NETBIRD_MANAGEMENT_SECRET` | 32-char Base64 secret for Management service |
| `NETBIRD_RELAY_SECRET` | 32-char Base64 secret for Relay service |
| `NETBIRD_TURN_SECRET` | 32-char Base64 secret for TURN server |
| `NETBIRD_TURN_PASSWORD` | Secure password for TURN server |
| `NETBIRD_DATASTORE_ENCRYPTION_KEY` | 32-char Base64 key for datastore encryption |
| `NETBIRD_AUTH_CLIENT_ID` | OIDC Client ID (default: `netbird-client`) |
| `NETBIRD_AUTH_AUDIENCE` | OIDC Audience (default: `netbird-client`) |
| `NETBIRD_IDP_MGMT_CLIENT_ID` | Management Client ID (default: `netbird-management`) |
| `NETBIRD_IDP_MGMT_CLIENT_SECRET` | Secret for the Management Client |
| `NETBIRD_DEFAULT_USER` | Initial dashboard user (default: `admin`) |
| `NETBIRD_DEFAULT_PASSWORD` | Initial dashboard user password |

---

#  QuickStart: Local Docker Deployment

This guide will walk you through deploying a full NetBird stack on your local machine for testing and development.

## Step 1: Clone Repository

```bash
git clone https://github.com/netbirdio/netbird.git
cd netbird/infrastructure/ansible
```

## Step 2: Configure Variables

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
https://<your-netbird-domain>
```
You can then log in with your Keycloak credentials.

### Verify Services
To confirm that all services are running, use the following command:
```bash
docker compose -f /opt/netbird/docker-compose.yml ps
```

---

#  Manual Remote SSH Deployment

Use this method to deploy NetBird to a remote server using a standard SSH connection.

## Step 1: Configure Variables

Follow the same steps as in the QuickStart guide to configure `group_vars/netbird_servers/vars.yml`.

## Step 2: Configure Inventory for Remote SSH

Edit `inventory.yaml` and update the host details:

```yaml
all:
  children:
    netbird_servers:
      hosts:
        netbird-primary:
          ansible_host: 1.2.3.4            # Replace with your server's public IP
          ansible_user: ubuntu             # Your SSH username (e.g., ubuntu, root)
          ansible_connection: ssh
          ansible_ssh_private_key_file: ~/.ssh/id_rsa  # Path to your private key
```

## Step 3: Run Deployment

Execute the Ansible playbook. Use `--ask-become-pass` if your user requires a password for `sudo`.

```bash
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass
```

## Step 4: Troubleshooting Connection

If you encounter SSH errors:
- Ensure you can SSH into the server manually: `ssh -i ~/.ssh/id_rsa ubuntu@1.2.3.4`
- Check that the `ansible_user` has `sudo` privileges.
- Ensure the server is running a supported OS (Ubuntu 20.04+ or Debian 11+).

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
3. **Removes all Docker volumes** associated with the project
4. Deletes the `/opt/netbird` deployment directory
5. Removes the `key-netbird` Docker network

## GitHub Actions Cleanup

1. Go to the **Actions** tab in your GitHub repository.
2. Select the **Ansible Deployment** workflow.
3. Click **Run workflow**.
4. Select **cleanup** in the "Action to perform" dropdown.
5. Click **Run workflow**.

OR, via GitHub CLI:

```bash
gh workflow run "Ansible Deployment" \
  -f action=cleanup \
  -f deployment_target=aws_ssm # or ssh_remote
```

---

#  Variable Reference Guide

## vars.yml - Configuration

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `netbird_domain` |  Yes | Your NetBird instance domain | `netbird.example.com` |
| `netbird_caddy_email` |  Yes | Email for Let's Encrypt | `admin@example.com` |
| `netbird_external_ip` |  Yes | Server public IP address (Required for TURN) | `1.2.3.4` |
| `keycloak_domain` |  Yes | Your Keycloak server domain | `idp.example.com` |
| `keycloak_port` |  Yes | Keycloak port | `8080` |
| `keycloak_admin_password` |  Yes | Keycloak admin password | `admin-pass` |
| `idp_service_name` |  Yes | Internal IdP service name | `keycloak` |
| `netbird_realm` |  Yes | Realm name to create | `netbird` |

## Secure Auto-Generation

The playbook and GitHub pipeline are designed for **Zero-Config Security**. If you leave optional secrets (Management, Relay, TURN, Datastore) empty in GitHub Secrets or `vars.yml`, the pipeline will:
1. **Automatically generate** secure, cryptographically strong random keys.
2. **Sanitize and validate** the keys to ensure they meet NetBird's encoding requirements (Base64, 32/24 chars).
3. **Persist** them to the target server's configuration files.

You only *need* to provide your Domain and Keycloak credentials; the rest can be handled automatically.

If you prefer to manually generate them:

```bash
# Generate 32-character secret (for management, relay, datastore)
openssl rand -base64 32

# Generate 24-character password (for TURN)
openssl rand -base64 24
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

#  Troubleshooting

### Keycloak Connectivity
If the playbook fails at "Get admin token", ensure:
1. `keycloak_domain` or `keycloak_auth_url` is correctly set.
2. The Keycloak server is reachable from the machine running Ansible.
3. If using self-signed certificates, set `keycloak_validate_certs: false` in `vars.yml`.

### Docker Network Issues
If you see "network key-netbird not found", ensure you ran:
```bash
docker network create key-netbird
```

### AWS SSM Failures
- Ensure the target instance has the **SSM Agent** running.
- Ensure the instance has an IAM Role with `AmazonSSMManagedInstanceCore`.
- Ensure the `AWS_S3_BUCKET` secret is set and the instance has access to it.

---

#  Security Best Practices

- **GitHub Secrets**: Store sensitive values only in GitHub, not in repo
- **SSH Keys**: Use strong keys, `chmod 600`, never commit them
- **Keycloak**: Use strong admin password, restrict access
- **Firewall**: Only open necessary ports (80, 443, 3478/UDP)
- **TLS**: Always use HTTPS in production (Caddy auto-handles)
- **Updates**: Keep images updated regularly via Docker pulls

