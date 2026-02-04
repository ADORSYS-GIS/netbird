# Netbird Self-Hosted Automation Suite

This directory contains Ansible playbooks to automate the management of a self-hosted Netbird instance integrated with Keycloak.

## Prerequisites

- **Ansible 2.10+** installed on your control node.
- **Required Collections**:
  ```bash
  ansible-galaxy collection install community.general community.docker
  ```
- **Keycloak Admin Access**: Credentials for the Keycloak Master realm or the specific realm used by Netbird.
- **Netbird API Token**: A valid personal access token from your Netbird dashboard.

## File Structure

- `vars.yml`: Central configuration file for secrets, URLs, and user lists.
- `add_users.yml`: Playbook for adding users to Keycloak.
- `add_peers.yml`: Playbook for installing Netbird and enrolling peers.

## Usage Guide

### 1. Configuration

Edit [vars.yml](./vars.yml) and update the following placeholders:
- `keycloak_url`: Your Keycloak instance URL.
- `netbird_mgmt_url`: Your Netbird Management API URL.
- `netbird_api_token`: Your Netbird API token.
- `netbird_users`: List of users to be provisioned in Keycloak.

### 2. Identity Management (Keycloak)

To provision users defined in `vars.yml` into Keycloak:
```bash
ansible-playbook -i your_inventory_file add_users.yml
```

### 3. Peer Enrollment

To install the Netbird agent and register hosts:
```bash
ansible-playbook -i your_inventory_file add_peers.yml
```

#### Enrollment Options:
- **Native Installation**: Default behavior. Supports Ubuntu, Debian, RHEL, and CentOS.
- **Docker Installation**: Set `netbird_docker_enabled: true` in your inventory or `vars.yml` for specific hosts to run Netbird as a container.
- **Peer-to-User/Group Association**: To assign a peer to a specific identity, use `netbird_auto_groups` in your inventory.
  ```yaml
  # Example inventory.yaml
  all:
    hosts:
      workstation-1:
        netbird_auto_groups: ["group-id-for-john"] # Peer will be associated with John's group
  ```

## How it Works

1. **Dynamic Setup Keys**: Before enrolling a peer, the playbook requests a short-lived (1 hour) ephemeral setup key from the Netbird API. This ensures keys are not hardcoded or reused indefinitely.
2. **OS Detection**: The suite automatically detects the target OS family to install the correct repository and package.
3. **Docker Support**: For containerized environments, it deploys the official Netbird image with `NET_ADMIN` capabilities and host networking for proper VPN interface operation.
