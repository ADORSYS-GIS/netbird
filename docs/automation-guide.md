# NetBird Automation & Lifecycle Management Guide

This guide provides detailed documentation for the infrastructure automation tools provided in this repository, focusing on Ansible and GitHub Actions.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Automation Components](#automation-components)
3. [Ansible Playbook Details](#ansible-playbook-details)
4. [GitHub Actions Pipeline](#github-actions-pipeline)
5. [Keycloak Automation](#keycloak-automation)
6. [Cleanup and Reset](#cleanup-and-reset)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The automation stack deploys NetBird in a production-ready configuration using:
- **Caddy**: As a reverse proxy with automatic TLS (Let's Encrypt).
- **Keycloak**: As the Identity Provider (OIDC).
- **Docker Compose**: Orchestrates NetBird services (Management, Signal, Relay, Dashboard).
- **Coturn**: Handles STUN/TURN for NAT traversal.

## Automation Components

- **Ansible Playbook** (`infrastructure/ansible/playbook.yaml`): The core orchestrator that prepares the system, configures Keycloak, generates service configurations, and starts the stack.
- **Keycloak Setup Script** (`infrastructure/scripts/keycloak-setup.sh`): A bash utility used by both the playbook and the CI/CD pipeline to automate Keycloak realm and client creation.
- **GitHub Workflow** (`.github/workflows/ansible-deploy.yml`): Provides a "Push-to-Deploy" experience with support for manual triggers and environment cleanup.

## Ansible Playbook Details

The playbook is designed to be **idempotent** and **self-healing**.

### Key Features:
- **Automatic Secret Generation**: If service secrets are not provided in `vars.yml`, they are automatically generated using secure random strings and base64 encoded.
- **Dynamic Keycloak Configuration**: It can detect if Keycloak needs to be configured and will automatically create the Realm, Clients (Web and Management), Protocol Mappers, and a default Admin user.
- **Tag-based Execution**:
  - `config`: Only update configuration files and restart services.
  - `cleanup`: Remove the entire deployment and clean up Keycloak.
  - `debug`: Show non-sensitive debug information.

### Usage:
```bash
ansible-playbook -i inventory.yaml playbook.yaml
```

## GitHub Actions Pipeline

The CI/CD pipeline supports two main deployment targets: **SSH Remote** and **AWS SSM**.

### Action Inputs:
- `action`: Choose between `deploy` (default) or `cleanup`.
- `deployment_target`: Choose between `ssh_remote` or `aws_ssm`.

### Secrets Management:
The pipeline pulls secrets from GitHub Repository Secrets and passes them securely to Ansible. If `KEYCLOAK_URL` is provided, it will first run the automated setup script to ensure the IdP is ready.

## Keycloak Automation

The automation ensures that:
1. A **NetBird Realm** is created.
2. A **Public Client** (`netbird-client`) is configured with correct Redirect URIs and Web Origins.
3. A **Confidential Client** (`netbird-management`) is created for API access.
4. **Protocol Mappers** for `audience` and `groups` are added to the tokens.
5. A **Default Admin User** is provisioned for immediate access.

### Custom Credentials:
You can customize the default user and password by setting the following variables in `vars.yml` or GitHub Secrets:
- `NETBIRD_DEFAULT_USER`: Defaults to `admin`.
- `NETBIRD_DEFAULT_PASSWORD`: If set to `<YOUR_DEFAULT_USER_PASSWORD>` or left empty, a secure random password will be generated and printed in the logs.

**Note**: If you change the password in your configuration after a deployment, the automation will update the password for the existing user in Keycloak on the next run.

## Cleanup and Reset

The cleanup routine is designed for a total environment reset.

### What is removed:
- All Docker containers and volumes associated with the project.
- The `/opt/netbird` deployment directory.
- The custom Docker network `key-netbird`.
- The entire **Keycloak Realm** created for NetBird.

### How to trigger:
**Via CLI:**
```bash
ansible-playbook -i inventory.yaml playbook.yaml --tags cleanup
```

**Via GitHub Actions:**
Run the `Ansible Deployment` workflow manually and select the `cleanup` action.

## Troubleshooting

### 'nb_management_secret' is undefined
This usually occurs if the sanitization block was skipped. Ensure you are using the latest version of the playbook where the variable finalization block is marked with `tags: [always]`.

### Keycloak 'invalid_uri' or 'invalid_audience'
These are typically caused by missing Protocol Mappers or incorrect Redirect URIs. The automated setup script resolves these by explicitly adding the `oidc-audience-mapper` and `oidc-group-membership-mapper`.

### Docker Network Conflicts
If the `key-netbird` network already exists with a different driver, the playbook might fail. The cleanup routine will remove it, allowing for a fresh start.
