# Getting Started

Complete guide for deploying NetBird infrastructure on existing VMs.

## Prerequisites

Before starting deployment, ensure you have the following:

### Required Tools

- **Terraform**: >= 1.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Ansible**: >= 2.10 ([Install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- **Git**: Latest version
- **Cloud CLI** (if using cloud provider):
  - AWS CLI for AWS
  - gcloud CLI for GCP
  - Azure CLI for Azure

### Cloud Requirements

- Existing VMs with SSH access
- Minimum 3 vCPUs, 4GB RAM total across VMs
- At least one VM with public IP for reverse proxy
- Ability to tag VMs (for auto-discovery)

### External Requirements

- Domain name (e.g., `netbird.example.com`)
- Ports 80/443 accessible for Let's Encrypt
- Keycloak or Zitadel instance for SSO

### Cloud Authentication

Configure cloud provider CLI:

**AWS**:
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

aws sts get-caller-identity  # Verify
```

**Expected output**:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

**GCP**:
```bash
gcloud auth login
# Opens browser for authentication

gcloud auth application-default login
# Opens browser for application default credentials

gcloud projects list  # Verify
```

**Expected output**:
```
PROJECT_ID          NAME                PROJECT_NUMBER
my-project-123456   My Project          123456789012
```

**Azure**:
```bash
az login
# Opens browser for authentication

az account show  # Verify
```

**Expected output**:
```json
{
  "id": "12345678-1234-1234-1234-123456789012",
  "name": "My Subscription",
  "state": "Enabled",
  "isDefault": true
}
```

## Deployment Overview

The deployment consists of three phases:

1. Infrastructure Discovery (Terraform)
2. DNS Configuration
3. Server Configuration (Ansible)

## Phase 1: Infrastructure Discovery

Terraform discovers existing VMs and configures database and Keycloak.

### Steps

1. **Navigate to infrastructure directory**:
   ```bash
   cd infrastructure/ansible-stack
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```
   
   **Expected output**:
   ```
   Initializing the backend...
   Initializing provider plugins...
   - Finding latest version of hashicorp/aws...
   - Installing hashicorp/aws v5.31.0...
   
   Terraform has been successfully initialized!
   ```

3. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars
   ```

   **Critical variables to configure**:
   - `cloud_provider`: `aws`, `gcp`, `azure`, or `multi`
   - `netbird_domain`: Your domain (e.g., `vpn.example.com`)
   - `aws_tag_filters` / `gcp_label_filters` / `azure_tag_filters`: Tags to discover VMs
   - `database_type`: `sqlite`, `postgresql`, or `mysql`
   - `keycloak_url`: Your Keycloak instance URL
   - `keycloak_admin_client_secret`: Admin CLI secret from Keycloak

   See [configuration-reference.md](./configuration-reference.md) for all options.

4. **Review the plan**:
   ```bash
   terraform plan
   ```
   
   **Expected output**:
   ```
   Terraform will perform the following actions:
   
     # module.inventory.data.aws_instances.netbird will be read during apply
     # module.keycloak.keycloak_realm.netbird will be created
     + resource "keycloak_realm" "netbird" {
         + realm = "netbird"
         ...
     }
   
   Plan: 3 to add, 0 to change, 0 to destroy.
   ```
   
   **Review carefully**: Ensure discovered VMs match your expectations.

5. **Apply configuration**:
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted.
   
   **Expected output**:
   ```
   module.inventory.data.aws_instances.netbird: Reading...
   module.keycloak.keycloak_realm.netbird: Creating...
   module.keycloak.keycloak_openid_client.netbird: Creating...
   
   Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
   
   Outputs:
   
   inventory_path = "../../configuration/ansible/inventory/terraform_inventory.yaml"
   management_nodes = [
     "10.0.1.10",
     "10.0.1.11",
   ]
   reverse_proxy_public_ip = "54.123.45.67"
   ```

### Terraform Outputs

After successful apply, Terraform generates:

- **Ansible inventory**: `../../configuration/ansible/inventory/terraform_inventory.yaml`
  ```bash
  cat ../../configuration/ansible/inventory/terraform_inventory.yaml
  ```
  
  **Expected structure**:
  ```yaml
  all:
    children:
      management:
        hosts:
          management-node-1:
            ansible_host: 10.0.1.10
          management-node-2:
            ansible_host: 10.0.1.11
      reverse_proxy:
        hosts:
          reverse-proxy-1:
            ansible_host: 54.123.45.67
  ```

- **Database connection details**: Stored in Terraform outputs
- **Keycloak credentials**: Client ID and secret for NetBird authentication

## Phase 2: DNS Configuration

Point your domain to the reverse proxy.

1. **Get reverse proxy public IP**:
   ```bash
   # From Terraform output
   cd infrastructure/ansible-stack
   terraform output reverse_proxy_public_ip
   ```
   
   **Expected output**:
   ```
   "54.123.45.67"
   ```

2. **Create DNS A Record**:
   
   In your DNS provider (Route53, Cloudflare, etc.):
   - **Name**: `vpn.example.com` (your `netbird_domain`)
   - **Type**: `A`
   - **Value**: `54.123.45.67` (reverse proxy public IP)
   - **TTL**: `300` (5 minutes)

3. **Verify DNS propagation**:
   ```bash
   dig vpn.example.com +short
   ```
   
   **Expected output**:
   ```
   54.123.45.67
   ```
   
   **Note**: DNS propagation may take 5-30 minutes. Wait until the command returns the correct IP before proceeding.
   
   **Verify from multiple DNS servers**:
   ```bash
   # Google DNS
   dig @8.8.8.8 vpn.example.com +short
   
   # Cloudflare DNS
   dig @1.1.1.1 vpn.example.com +short
   ```

## Phase 3: Server Configuration

Ansible installs and configures NetBird services.

### Steps

1. **Navigate to configuration directory**:
   ```bash
   cd ../../configuration/ansible
   ```

2. **Verify inventory file exists**:
   ```bash
   ls -la inventory/terraform_inventory.yaml
   ```
   
   **Expected output**:
   ```
   -rw-r--r-- 1 user user 1234 Feb 16 14:30 inventory/terraform_inventory.yaml
   ```

3. **Test connectivity to all hosts**:
   ```bash
   ansible -i inventory/terraform_inventory.yaml all -m ping
   ```
   
   **Expected output**:
   ```
   management-node-1 | SUCCESS => {
       "changed": false,
       "ping": "pong"
   }
   management-node-2 | SUCCESS => {
       "changed": false,
       "ping": "pong"
   }
   reverse-proxy-1 | SUCCESS => {
       "changed": false,
       "ping": "pong"
   }
   ```

4. **Run deployment playbook**:
   ```bash
   ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
   ```
   
   **Expected duration**: 5-10 minutes
   
   **Expected output** (abbreviated):
   ```
   PLAY [Deploy NetBird Infrastructure] ******************************************
   
   TASK [Gathering Facts] *********************************************************
   ok: [management-node-1]
   ok: [reverse-proxy-1]
   
   TASK [common : Update apt cache] ***********************************************
   changed: [management-node-1]
   
   TASK [docker : Install Docker] *************************************************
   changed: [management-node-1]
   
   TASK [netbird-server : Deploy NetBird containers] ******************************
   changed: [management-node-1]
   
   TASK [reverse-proxy : Deploy Caddy] ********************************************
   changed: [reverse-proxy-1]
   
   PLAY RECAP *********************************************************************
   management-node-1  : ok=25   changed=15   unreachable=0   failed=0
   management-node-2  : ok=25   changed=15   unreachable=0   failed=0
   reverse-proxy-1    : ok=18   changed=12   unreachable=0   failed=0
   ```
   
   **What gets installed**:
   - Docker and Docker Compose
   - NetBird containers (management, signal, dashboard)
   - Caddy reverse proxy with automatic HTTPS
   - UFW firewall rules (preserving existing rules)
   - Database client tools (if using PostgreSQL/MySQL)
   
   **If errors occur**: See [troubleshooting.md](./troubleshooting.md)

## Verification

### Service Health

**1. Verify NetBird API is accessible**:

```bash
curl -f https://vpn.example.com/health
```

**Expected output**:
```json
{"status":"ok"}
```

**2. Check HTTPS certificate** (Let's Encrypt should be automatically provisioned):

```bash
curl -vI https://vpn.example.com 2>&1 | grep -i "subject\|issuer"
```

**Expected output**:
```
* subject: CN=vpn.example.com
* issuer: C=US; O=Let's Encrypt; CN=R3
```

**3. Access the NetBird Dashboard**:

Open in browser:
```
https://vpn.example.com
```

**Expected**: NetBird login page with Keycloak authentication

**4. Verify all containers are running**:

```bash
ansible -i inventory/terraform_inventory.yaml management -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

**Expected output**:
```
management-node-1 | CHANGED | rc=0 >>
NAMES                STATUS
netbird-management   Up 10 minutes (healthy)
netbird-signal       Up 10 minutes (healthy)
netbird-dashboard    Up 10 minutes (healthy)

management-node-2 | CHANGED | rc=0 >>
NAMES                STATUS
netbird-management   Up 10 minutes (healthy)
netbird-signal       Up 10 minutes (healthy)
netbird-dashboard    Up 10 minutes (healthy)
```

### Security Validation

Run automated security checks:

```bash
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/validate-security.yml
```

**Expected output**:
```
PLAY [Validate Security Configuration] *****************************************

TASK [Check reverse proxy has public IP] **************************************
ok: [reverse-proxy-1]

TASK [Check management nodes use private IPs] *********************************
ok: [management-node-1]
ok: [management-node-2]

TASK [Verify UFW is enabled] **************************************************
ok: [management-node-1]

TASK [Check no unauthorized ports exposed] ************************************
ok: [management-node-1]

PLAY RECAP *********************************************************************
management-node-1  : ok=10   changed=0   unreachable=0   failed=0
management-node-2  : ok=10   changed=0   unreachable=0   failed=0
reverse-proxy-1    : ok=8    changed=0   unreachable=0   failed=0
```

**Validates**:
- ✅ Reverse proxy has public IP for external access
- ✅ Management nodes use private IPs only
- ✅ No critical ports (5432, 8080, 10000) exposed publicly
- ✅ UFW firewall rules configured correctly
- ✅ Services binding to correct interfaces

**If any checks fail**: Review [security-hardening.md](../../../docs/operations/security-hardening.md)

## Post-Deployment

1. Configure monitoring (see [Monitoring Guide](../../../docs/operations/monitoring-alerting.md))
2. Set up backups (see [Disaster Recovery](../../../docs/operations/disaster-recovery.md))
3. Review security (see [Security Hardening](../../../docs/operations/security-hardening.md))
4. Enroll NetBird clients via dashboard

## Troubleshooting

If deployment fails, see [troubleshooting.md](./troubleshooting.md) for solutions.

## Related Documentation

- [Configuration Reference](./configuration-reference.md) - All variable options
- [Database Migration](./database-migration.md) - Switching database backends
- [Upgrade Guide](./upgrade-guide.md) - Upgrading NetBird versions
