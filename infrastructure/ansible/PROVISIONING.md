# NetBird Peer & User Provisioning Automation

This playbook automates the process of creating NetBird groups, policies, and setup keys, and installing the NetBird agent on target machines (Peers).

## Features

- **Automated API Interaction**: Creates a NetBird group and a "self-communication" policy for a specific user.
- **Dynamic Setup Keys**: Generates a reusable setup key associated with the user's group.
- **Multi-OS Support**: Installs NetBird on Debian/Ubuntu and RHEL/CentOS/Fedora systems.
- **Docker Support**: Can deploy the NetBird agent as a Docker container.
- **Idempotent**: Safe to run multiple times.

## Prerequisites

1. **NetBird API Token**: A Personal Access Token (PAT) from your NetBird dashboard (Settings > Tokens).
2. **Management URL**: The URL of your NetBird management service (e.g., `https://netbird.example.com`).
3. **Ansible**: Installed on your control node.

## Environment Variables

The playbook uses the following environment variables for API authentication:

- `NETBIRD_API_TOKEN`: Your NetBird Personal Access Token.
- `NETBIRD_MANAGEMENT_URL`: (Optional) Your NetBird Management URL. Defaults to `https://{{ netbird_domain }}`.

## Usage

### 1. Define your Inventory

Create or update an inventory file (e.g., `peers_inventory.yaml`) with your target peers:

```yaml
all:
  hosts:
    peer-1:
      ansible_host: 1.2.3.4
      ansible_user: ubuntu
    peer-2:
      ansible_host: 5.6.7.8
      ansible_user: centos
```

### 2. Run the Playbook

Run the playbook specifying the `target_user` and `target_hosts`:

```bash
export NETBIRD_API_TOKEN="your_token_here"
export NETBIRD_MANAGEMENT_URL="https://netbird.example.com"

ansible-playbook -i peers_inventory.yaml provision_peers.yaml \
  -e "target_user=john-doe" \
  -e "target_hosts=peer-1,peer-2" \
  -e "netbird_domain=netbird.example.com"
```

### 3. Deploy via Docker

If you prefer to run NetBird in a Docker container on the target peers:

```bash
ansible-playbook -i peers_inventory.yaml provision_peers.yaml \
  -e "target_user=john-doe" \
  -e "use_docker=true"
```

## How it works

1. **Role `netbird_api`**:
    - Connects to your NetBird Management API.
    - Ensures a group `group-{{ target_user }}` exists.
    - Ensures a policy `policy-{{ target_user }}` exists, allowing all traffic within that group.
    - Generates a reusable setup key linked to that group.
2. **Role `netbird_client`**:
    - Installs the NetBird agent on target hosts using the native package manager (`apt` or `yum/dnf`) or Docker.
    - Runs `netbird up` with the generated setup key.

## Troubleshooting

- **API Authentication**: Ensure `NETBIRD_API_TOKEN` is valid and has sufficient permissions.
- **Network Connectivity**: Target peers must be able to reach the NetBird Management URL.
- **Docker**: If `use_docker=true`, ensure Docker is installed and the `community.docker` Ansible collection is available.
