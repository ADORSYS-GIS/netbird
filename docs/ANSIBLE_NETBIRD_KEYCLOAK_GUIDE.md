# NetBird + Keycloak Self-Hosted Deployment Guide (Ansible)

## Overview
This guide describes how to provision a secure, self-hosted NetBird control plane with Keycloak as the OpenID Connect (OIDC) identity provider using Ansible automation. The deployment targets a single Ubuntu 24.04 host and exposes both services behind HTTPS and self-signed certificates rooted in a local trusted certificate authority (CA). The tutorial includes:

1. Automated provisioning playbook layout
2. TLS certificate generation with a shared CA for cross-container trust
3. Container orchestration via Docker Compose for Traefik, Keycloak, and NetBird
4. Post-deployment hardening steps aligned with Zero Trust principles
5. Operational procedures for ACLs, split tunneling, SSO enforcement, and key rotation

## Repository Layout
```
ansible/
├── group_vars/
│   └── all.yml
├── inventory/
│   └── hosts.ini
├── playbook.yml
├── tasks/
│   ├── keycloak.yml
│   ├── netbird.yml
│   ├── os_prereqs.yml
│   ├── post_deploy.yml
│   ├── tls_certs.yml
│   └── traefik.yml
└── templates/
    ├── keycloak-docker-compose.yml.j2
    ├── netbird-docker-compose.yml.j2
    ├── traefik-docker-compose.yml.j2
    └── traefik-dynamic.yml.j2
```

## Prerequisites
- **Control host**: Ubuntu 24.04 server reachable via SSH (playbook uses `localhost` connection for simplicity).
- **Ansible**: Installed on the control machine and able to run collections (e.g., `community.crypto`, `community.docker`).
- **Privileges**: sudo rights on the target host to install packages, manage Docker, and drop files under `/opt`.
- **DNS Resolution**: `netbird.localhost` and `keycloak.localhost` should resolve to the host's IP on the testing workstation (e.g., via `/etc/hosts`).

## Step-by-Step Deployment Tutorial

### 1. Prepare Host Variables
1. Update `ansible/group_vars/all.yml` with secure credentials:
   - **keycloak_admin_password**: Replace the default with a strong secret.
   - **keycloak_client_secret**: Match the client secret that NetBird will use.
   - **netbird_setup_key**: Generate via NetBird or placeholder for first-run bootstrap.
   - **netbird_key_rotation_schedule**: Cron expression for WireGuard key rotation.

### 2. Inspect Inventory
1. Verify `ansible/inventory/hosts.ini` points to the intended host. For a remote server, replace `localhost` with `<host_ip_or_dns> ansible_user=<user>`.
2. Ensure SSH keys are configured if running against remote hosts.

### 3. Install Required Ansible Collections
1. On the control machine, run:
   ```bash
   ansible-galaxy collection install community.crypto community.docker
   ```
2. This ensures the playbook can generate certificates and control Docker Compose.

### 4. Run the Playbook
1. Execute the deployment:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbook.yml
   ```
2. The playbook performs the following:
   - Installs system dependencies and Docker engine.
   - Generates a local CA and server certificates for NetBird and Keycloak.
   - Installs the CA into the host trust store and updates trusted certificates.
   - Deploys Traefik as a reverse proxy with the generated certificates.
   - Launches Keycloak and NetBird containers with TLS termination handled by Traefik.
   - Obtains the NetBird CLI for post-deployment automation.

### 5. Local Trust Configuration
1. Copy `netbird_ca.crt` from `/opt/netbird/tls/` on the host to your local workstation.
2. Install the CA certificate into your local trust store so browsers and CLI tools trust `https://netbird.localhost` and `https://keycloak.localhost`:
   - **macOS**: Import into Keychain Access under System Roots.
   - **Linux**: Place under `/usr/local/share/ca-certificates/` and run `sudo update-ca-certificates`.
   - **Windows**: Use `certmgr.msc` to import into Trusted Root Certification Authorities.

### 6. Configure Keycloak Realm and Client
1. The playbook now automates realm, client, and group creation through the Keycloak Admin REST API.
2. After playbook completion, verify configuration in the Keycloak admin console (`https://keycloak.localhost/admin`).
3. Confirm:
   - Realm `netbird` exists with proper display name.
   - Client `netbird-client` includes redirect URIs and secret matching Ansible variables.
   - Groups listed in `keycloak_group_map` are present.
   - `groups` protocol mapper is enabled on the client.
4. Create or import user accounts and assign them to appropriate groups. Configure MFA and password policies as needed.

### 7. NetBird Dashboard Initial Configuration
1. Navigate to `https://netbird.localhost` and follow the onboarding wizard.
2. Provide the OIDC details generated in Keycloak if not already set via environment variables.
3. Import the generated setup key or create a new one within the dashboard to enroll clients.

### 8. Implement Default-Deny ACL Baseline
1. Confirm the `Default Deny` policy exists (created via automation). If not, add a policy with:
   - **Action**: `deny`
   - **Sources/Destinations**: `*`
   - **Precedence**: Highest (top of policy list)
2. Test connectivity between two enrolled peers; traffic should be blocked until allow rules are defined.

### 9. Define Least-Privilege Access Rules
1. Align NetBird Groups with Keycloak groups to inherit identity context.
2. For each service (e.g., database, CI), create resource groups.
3. Add allow policies:
   - **Source Group**: Identity-based group (e.g., `engineering`).
   - **Destination Group**: Service group (e.g., `svc-database`).
   - **Protocol/Port**: Restrict to required values (e.g., TCP/5432).
4. Document each policy justification for audits.
5. Validate network access using NetBird diagnostics.

### 10. Configure Split Tunneling & Per-Group DNS
1. In NetBird routes, define internal CIDR blocks (e.g., `10.10.0.0/16`) and assign them to relevant groups.
2. Configure DNS profiles per group:
   - **Servers**: Corporate DNS (e.g., `10.0.0.10`).
   - **Search Domains**: `corp.internal`.
3. Test from enrolled clients: ensure only intended subnets traverse the tunnel and DNS queries resolve via configured servers.

### 11. Enforce SSO/OIDC for All Users
1. Disable local NetBird credentials by ensuring `NB_ENABLE_AUTH` and `NB_AUTH_OIDC_ENABLED` are set to true.
2. Confirm login attempts redirect to Keycloak and that tokens include group claims (verify via browser developer tools or CLI `jwt.io`).

### 12. WireGuard Key Rotation Process
1. Decide rotation cadence (default weekly schedule defined as cron in `netbird_key_rotation_schedule`).
2. For ad-hoc rotations, run:
   ```bash
   netbird peer rotate-keys --all
   ```
3. Automate rotation via cron or CI pipelines calling NetBird CLI with appropriate tokens.
4. Monitor NetBird logs post-rotation for potential failures.

### 13. Observability & Maintenance
- **Audit Logs**: Export NetBird logs to SIEM for visibility into blocked attempts.
- **Backup Strategy**: Backup Keycloak realm and NetBird configuration directories under `/opt/netbird/compose/data`.
- **Policy Review**: Conduct quarterly reviews of ACLs and group memberships to maintain least privilege.

## Troubleshooting Tips
- **Certificate Warnings**: Ensure local CA trust installation. Check `openssl s_client -connect netbird.localhost:443` for certificate chains.
- **Container Networking**: Validate `netbird_net` Docker network and service health using `docker ps` and `docker logs`.
- **OIDC Failures**: Inspect Keycloak logs (`docker logs keycloak`) for client misconfiguration, mismatched secrets, or invalid redirect URIs.
- **ACL Misconfigurations**: Use NetBird dashboard policy tester or CLI commands to inspect policy evaluation order.

## Next Steps
- Integrate monitoring (Prometheus/Grafana) for service health.
- Automate Keycloak realm, client, and group provisioning with the bundled REST automation (see **Keycloak Automation** below). Consider Terraform for larger multi-environment setups.
- Expand playbook to support multi-node deployments with inventory groups and host variables for staging/production separation.

By following this guide, you establish a secure NetBird deployment with Keycloak as IdP, enforce Zero Trust access policies, and maintain continuous operations via Ansible-driven automation.