# NetBird Peer & User Provisioning Automation

This playbook automates the process of creating NetBird groups, policies, and setup keys, and installing the NetBird agent on target machines (Peers).

## Features

- **Automated API Interaction**: Creates a NetBird group and a "self-communication" policy for a specific user.
- **Keycloak Integration**: Automatically creates the user in your self-hosted Keycloak IdP if they don't exist.
- **Dynamic Setup Keys**: Generates a reusable setup key associated with the user's group.
- **Multi-OS Support**: Installs NetBird on Debian/Ubuntu and RHEL/CentOS/Fedora systems.
- **Docker Support**: Can deploy the NetBird agent as a Docker container.
- **Local & Remote**: Can be run against remote servers via SSH or against the local machine.

## Prerequisites

1. **NetBird API Token**: A Personal Access Token (PAT) from your NetBird dashboard (Settings > Tokens).
2. **Management URL**: The URL of your NetBird management service (e.g., `https://netbird.example.com`).
3. **Ansible Collections**:
   ```bash
   ansible-galaxy collection install community.docker community.general community.crypto
   ```
4. **Ansible**: Installed on your control node.

## Environment Variables

- `NETBIRD_API_TOKEN`: **(Required)** Your NetBird Personal Access Token.
- `NETBIRD_MANAGEMENT_URL`: (Optional) Your NetBird Management URL. Defaults to `https://{{ netbird_domain }}`.

---

## Deployment Scenarios

### Scenario A: Provision Local Machine (Localhost)

If you want to install and register NetBird on the **same machine** where you are running Ansible:

```bash
export NETBIRD_API_TOKEN="your_token_here"

# Run against localhost
ansible-playbook provision_peers.yaml \
  -i localhost, \
  -e "target_user=my-local-user" \
  -e "netbird_domain=netbird.example.com" \
  --ask-become-pass
```

### Scenario B: Provision Remote Servers (SSH)

If you want to install NetBird on one or more **remote servers**:

1. **Define your Inventory** (`inventory.yaml`):
   ```yaml
   all:
     hosts:
       peer-1: { ansible_host: 1.2.3.4, ansible_user: ubuntu }
       peer-2: { ansible_host: 5.6.7.8, ansible_user: centos }
   ```

2. **Run the Playbook**:
   ```bash
   export NETBIRD_API_TOKEN="your_token_here"

   # Ansible will automatically handle the local API part and the remote peer part
   ansible-playbook -i inventory.yaml provision_peers.yaml \
     -e "target_user=john-doe" \
     -e "netbird_domain=netbird.example.com"
```


## Keycloak Integration (Self-Hosted)

If you are using the self-hosted stack provided in this repository, you can also automate user creation in Keycloak.

Pass the Keycloak admin credentials to the playbook:

```bash
ansible-playbook -i inventory.yaml provision_peers.yaml \
  -e "target_user=new-user" \
  -e "netbird_domain=netbird.example.com" \
  -e "keycloak_admin_password=your_keycloak_admin_pass"
```

**Variables for Keycloak customization:**
- `keycloak_admin_user`: Defaults to `admin`.
- `keycloak_admin_password`: Your Keycloak admin password.
- `netbird_realm`: Defaults to `netbird`.
- `netbird_user_password`: Initial password for the new user (defaults to `Netbird123!`).

---

## How it works

1. **Play 1: API Provisioning (Local)**: The first part of the playbook always runs on `localhost` to ensure the necessary groups and policies exist in your NetBird Management service (and Keycloak if configured) and to generate a setup key.
2. **Play 2: Peer Installation**: 
    - Installs the NetBird agent on target hosts using the native package manager (`apt` or `yum/dnf`) or Docker.
    - Runs `netbird up` with the generated setup key retrieved from the local play.

## Troubleshooting

- **API Authentication**: Ensure `NETBIRD_API_TOKEN` is valid and has sufficient permissions.
- **Sudo Access**: When running locally or remotely without a root user, use `--ask-become-pass` (or `-K`) to provide the sudo password.
- **Docker**: If `use_docker=true`, ensure Docker is installed and the `community.docker` Ansible collection is available.
- **Localhost in Inventory**: If you get errors about `localhost` not being found, ensure it's either in your inventory file or that your Ansible configuration allows the implicit `localhost`.
