# NetBird with Caddy Deployment Automation

This directory contains an Ansible playbook to automate the deployment of NetBird with Caddy as a reverse proxy, configured to use Keycloak as the IdP. Caddy handles SSL termination and routes traffic to the various NetBird services.

## Prerequisites

- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/engine/install/)
- [Keycloak](https://www.keycloak.org/getting-started/getting-started-docker)
- An Ubuntu 20.04+ or Debian 11+ server
- Ansible installed on your control machine
- SSH access to the target server with a user that has `sudo` privileges
- A registered domain name pointing to the public IP address of your server
- An email address for Caddy's ACME (Let's Encrypt) certificate registration

## Features

- **NetBird Service Deployment**: Deploys NetBird Management, Signal, Relay, and CoTURN services using Docker Compose
- **Caddy Integration**: Configures Caddy as a reverse proxy with automatic SSL/TLS certificate management via Let's Encrypt
- **Templated Configuration**: All configuration files are generated from Jinja2 templates with dynamic variable substitution
- **Keycloak Integration**: Includes placeholders for Keycloak (OpenID Connect) configuration. See [Keycloak setup guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak)

## Directory Structure

```
infrastructure/ansible/
├── inventory.yaml    # Host definitions and all variables in one file
├── playbook.yml      # Main Ansible playbook with deployment tasks
├── templates/        # Jinja2 templates for configuration files
│   ├── Caddyfile.j2
│   ├── docker-compose.yml.j2
│   ├── management.json.j2
│   └── turnserver.conf.j2
└── README.md
```

## Deployment Instructions

### 1. Clone the repository

```bash
git clone https://github.com/netbirdio/netbird.git
cd netbird/infrastructure/ansible
```

### 2. Setup Keycloak

Before deploying NetBird, a configured Keycloak instance is required:

1. Follow the [NetBird Keycloak setup guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak).
2. Ensure the client is configured with the correct redirect URIs for your NetBird domain.
3. Record the following values for the Ansible inventory:
   - **Client ID**
   - **Audience** (typically the same as Client ID)
   - **Authority URL** (e.g., `https://idp.example.com/realms/myrealm`)

### 3. Configure your deployment

Edit `inventory.yaml` with your server details and Keycloak configuration:

```yaml
all:
  children:
    netbird_servers:
      hosts:
        netbird-primary:
          ansible_host: YOUR_SERVER_IP        # Your server's public IP
          ansible_user: YOUR_USERNAME          # SSH username (e.g., ubuntu)
      vars:
        # Domain Configuration
        netbird_domain: "your-domain.com"
        netbird_caddy_email: "your-email@example.com"
        netbird_external_ip: "YOUR_SERVER_PUBLIC_IP"
        
        # Keycloak (OIDC) Configuration - Use values from Step 2
        netbird_auth_audience: "netbird-client"
        netbird_auth_client_id: "netbird-client"
        netbird_auth_authority: "https://your.keycloak.domain/realms/your-realm"
        
        # Secrets - REPLACE WITH STRONG RANDOM VALUES
        netbird_management_secret: "YOUR_MANAGEMENT_SECRET"
        netbird_relay_secret: "YOUR_RELAY_SECRET"
        netbird_turn_secret: "YOUR_TURN_SECRET"
        netbird_turn_password: "YOUR_TURN_PASSWORD"
        netbird_datastore_encryption_key: "YOUR_DATASTORE_ENCRYPTION_KEY"
```

**IMPORTANT**: Replace all placeholder values with your actual configuration and generate strong, random secrets for production use. Consider using Ansible Vault to encrypt sensitive values.

### 4. Run the deployment

```bash
ansible-playbook -i inventory.yaml playbook.yml --ask-become-pass
```

The `--ask-become-pass` flag will prompt you for your `sudo` password on the target server.

## Troubleshooting

- **Firewall Issues**: Ensure ports `80`, `443`, `3478/udp`, `51820/udp`, and `51821/udp` are open
- **Caddy Certificate Issues**: Check Caddy logs for Let's Encrypt errors. Verify DNS records point to your server's public IP
- **Docker Service Issues**: Use `docker-compose logs` in `/opt/netbird` to inspect service logs

## Accessing NetBird

After successful deployment, access the NetBird dashboard at:
```
https://your-domain.com
```
