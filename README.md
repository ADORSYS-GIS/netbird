# NetBird Infrastructure Lifecycle Automation

Production-grade Infrastructure-as-Code (IaC) for NetBird deployments, featuring automated lifecycle management, Identity Provider (IdP) orchestration, and secure reverse proxy configuration.

## 🚀 Key Features

- **Full Lifecycle Automation**: One-click deployment and complete environment destruction (Cleanup) via Ansible or GitHub Actions.
- **Keycloak IdP Orchestration**: Automatic configuration of Keycloak realms, OIDC clients (Web & Management), API scopes, and protocol mappers.
- **Secure Reverse Proxy**: Integrated Caddy setup with automatic Let's Encrypt TLS.
- **Flexible Provisioning**: Support for SSH Remote hosts and AWS SSM (Systems Manager).
- **Security Hardening**: Automated secret generation, PKCE enforcement, and secure redirect policies.

## 🛠 Deployment Options

### 1. GitHub Actions (Production-Ready CI/CD)
The recommended way to manage your NetBird infrastructure. Supports manual triggers and automated push-to-deploy.

- **Action**: `Ansible Deployment`
- **Features**: 
  - Toggle between `deploy` and `cleanup`.
  - Targeted deployment to `ssh_remote` or `aws_ssm`.
  - Automatic Keycloak setup using repository secrets.
- **Documentation**: [CI/CD Automation Guide](./docs/automation-guide.md)

### 2. Ansible (Self-Hosted Orchestration)
Idempotent and self-healing deployment script for manual execution.

- **Guide**: [Ansible Deployment Guide](./infrastructure/ansible/README.md)
- **Features**: Automatic secret generation and Keycloak API integration.

### 3. Quickstart / Legacy Options
For testing or specific manual configurations.

- **Zitadel Quickstart**: [Setup Guide](./infrastructure/scripts/README.md)
- **Manual Caddy**: [Manual Deployment](./docs/caddy-deployment.md)

## 🔐 Custom Credentials

You can easily customize the initial admin access by setting these variables (GitHub Secrets or manual inputs):

- `KEYCLOAK_ADMIN_USER_SECRET`: Admin username (defaults to `admin`).
- `KEYCLOAK_ADMIN_PASSWORD_SECRET`: Custom password for the dashboard user. If left empty, a secure random password will be generated and displayed in the GitHub Actions deployment logs.

*Note: If you update the password secret after deployment, the automation will automatically sync the new password to Keycloak on the next run.*

## 🧹 Cleanup and Reset

The project includes a robust cleanup routine that performs a total reset:
- Stops all containers and **removes all Docker volumes** (including persistent data).
- Deletes the entire Keycloak Realm and associated clients.
- Removes all configuration directories (`/opt/netbird`).
- Resets the `key-netbird` Docker network.

You can trigger this by running the workflow with the `cleanup` action.

## 📚 Documentation

- [**Automation Guide**](./docs/automation-guide.md): Deep dive into the CI/CD and Ansible lifecycle.
- [**Ansible README**](./infrastructure/ansible/README.md): Variable definitions and local usage.
- [**Official NetBird Docs**](https://docs.netbird.io/): NetBird configuration and architecture.
