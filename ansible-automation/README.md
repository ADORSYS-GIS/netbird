# NetBird with Caddy Deployment Automation

This directory contains Ansible playbooks and roles to automate the deployment of NetBird with Caddy as a reverse proxy. Caddy handles SSL termination and routes traffic to the various NetBird services.

## Features

*   **Automated System Preparation**: Installs Docker, Docker Compose, and configures UFW firewall rules.
*   **NetBird Service Deployment**: Deploys NetBird Management, Signal, STUN, and TURN services using Docker Compose.
*   **Caddy Integration**: Configures Caddy as a reverse proxy for NetBird, including automatic SSL/TLS certificate management via Let's Encrypt.
*   **Templated Configuration**: All configuration files (`Caddyfile`, `docker-compose.yml`, `management.json`, `turnserver.conf`) are generated from Jinja2 templates, allowing for dynamic variable substitution.
*   **Keycloak Integration (Placeholders)**: Includes placeholders for Keycloak (OpenID Connect) configuration, allowing for easy integration with an external Identity Provider.

## Prerequisites

Before running this automation, ensure you have:

*   An Ubuntu 20.04+ or Debian 11+ server.
*   Ansible installed on your control machine.
*   SSH access to the target server with a user that has `sudo` privileges.
*   A registered domain name pointing to the public IP address of your server.
*   An email address for Caddy's ACME (Let's Encrypt) certificate registration.

## Directory Structure

*   `playbook.yml`: The main Ansible playbook to run the deployment.
*   `inventory/`: Contains host and group variable definitions.
    *   `hosts.yml`: Defines the target server(s).
    *   `group_vars/all.yml`: Contains global variables for the deployment, including domain names, IP addresses, and secrets.
*   `roles/`: Contains Ansible roles for modularizing tasks.
    *   `system-preparation/`: Role for installing Docker, Docker Compose, and configuring the firewall.
    *   `netbird-caddy-deployment/`: Role for generating configuration files and deploying NetBird and Caddy services.
*   `templates/`: Jinja2 templates for all configuration files.
    *   `Caddyfile.j2`: Caddy server configuration.
    *   `docker-compose.yml.j2`: Docker Compose file for NetBird services.
    *   `management.json.j2`: NetBird Management service configuration.
    *   `turnserver.conf.j2`: CoTURN server configuration.

## Deployment Instructions

1.  **Clone this repository**:
    ```bash
    git clone https://github.com/netbirdio/netbird.git
    cd netbird/ansible-automation
    ```

2.  **Configure your deployment variables**:
    Edit the `inventory/hosts.yml` and `inventory/group_vars/all.yml` files to match your environment.

    *   **`inventory/hosts.yml`**:
        ```yaml
        ---
        all:
          hosts:
            your_server_name:
              ansible_host: your_server_public_ip # e.g., 192.0.2.1
              ansible_user: your_ssh_username     # e.g., ubuntu
        ```

    *   **`inventory/group_vars/all.yml`**:
        Update the following variables:
        ```yaml
        ---
        # NetBird Domain Configuration
        netbird_domain: "your.netbird.domain" # e.g., netbird.example.com
        netbird_caddy_email: "your-email@example.com" # Email for Caddy's Let's Encrypt certificates
        netbird_external_ip: "your_server_public_ip" # e.g., 192.0.2.1

        # Generate strong secrets for these variables
        netbird_management_secret: "YOUR_MANAGEMENT_SECRET"
        netbird_signal_secret: "YOUR_SIGNAL_SECRET"
        netbird_turn_secret: "YOUR_TURN_SECRET"
        netbird_jwt_secret: "YOUR_JWT_SECRET"
        netbird_postgres_password: "YOUR_POSTGRES_PASSWORD"

        # Keycloak (OIDC) Configuration - Update AFTER Keycloak setup
        # These are placeholders. You will need to update them with actual values
        # from your Keycloak realm and client configuration.
        netbird_auth_audience: "netbird"
        netbird_auth_client_id: "netbird"
        netbird_auth_authority: "https://your.keycloak.domain/realms/netbird"
        ```
        **IMPORTANT**: Replace `YOUR_MANAGEMENT_SECRET`, `YOUR_SIGNAL_SECRET`, `YOUR_TURN_SECRET`, `YOUR_JWT_SECRET`, and `YOUR_POSTGRES_PASSWORD` with strong, randomly generated secrets.

3.  **Run the deployment playbook**:
    ```bash
    ansible-playbook -i inventory/hosts.yml playbook.yml --ask-become-pass
    ```
    The `--ask-become-pass` flag will prompt you for your `sudo` password on the target server.

4.  **Post-Deployment Keycloak Configuration**:
    After the NetBird services are deployed, you will need to manually configure your Keycloak instance (if you haven't already). Once Keycloak is set up and you have created a realm and client for NetBird, update the `netbird_auth_audience`, `netbird_auth_client_id`, and `netbird_auth_authority` variables in `inventory/group_vars/all.yml` with the correct values from your Keycloak setup.

    After updating these variables, you can re-run the playbook to apply the new Keycloak configuration to the NetBird management service:
    ```bash
    ansible-playbook -i inventory/hosts.yml playbook.yml --tags "netbird-caddy-deployment" --ask-become-pass
    ```

## Troubleshooting

*   **Firewall Issues**: Ensure ports `80`, `443`, `3478/udp`, `51820/udp`, and `51821/udp` are open on your server.
*   **Caddy Certificate Issues**: Check Caddy logs for errors related to Let's Encrypt. Ensure your domain's DNS records are correctly pointing to your server's public IP.
*   **Docker Service Issues**: Use `docker-compose logs` to inspect the logs of individual NetBird services for errors.