# NetBird Keycloak Deployment

Automated Ansible deployment for NetBird with Keycloak identity provider. Supports deploying a new Keycloak instance or integrating with an existing one.

## Quick Start

### Prerequisites

```bash
# Install Ansible
sudo apt update && sudo apt install ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml
```

### Option 1: Deploy New Keycloak (Deploy Mode)

**1. Configure target host** - Edit `inventory.ini`:
```ini
[keycloak]
localhost ansible_connection=local
```

**2. Configure Keycloak** - Edit `group_vars/keycloak.yml`:
```yaml
keycloak_deploy_mode: true
keycloak_external_mode: false
keycloak_host: "192.168.1.100.nip.io"  # Your IP + .nip.io
keycloak_valid_redirect_uris:
  - "https://YOUR_NETBIRD_DOMAIN/*"
  - "http://localhost:53000"
```

**3. Set passwords** - Edit `group_vars/all.yml`:
```yaml
vault_keycloak_admin_password: "ChangeMe123!"
vault_keycloak_db_password: "ChangeMe456!"
```

**4. Run deployment**:
```bash
ansible-playbook -i inventory.ini setup_and_run.yml
```

**5. Access Keycloak**: `https://YOUR_DOMAIN/admin` (user: `admin`)

---

### Option 2: Use Existing Keycloak (External Mode)

**1. Configure target host** - Edit `inventory.ini` (same as above)

**2. Configure external Keycloak** - Edit `group_vars/keycloak.yml`:
```yaml
keycloak_deploy_mode: false
keycloak_external_mode: true
keycloak_oidc_configuration_endpoint: "https://your-keycloak.com/realms/netbird/.well-known/openid-configuration"
keycloak_valid_redirect_uris:
  - "https://netbird.yourcompany.com/*"
  - "http://localhost:53000"
```

**3. Set credentials** - Edit `group_vars/all.yml`:
```yaml
vault_netbird_backend_client_secret: "get-from-keycloak-admin"
```

**4. Run configuration**:
```bash
ansible-playbook -i inventory.ini setup_and_run.yml
```

---

## Configuration Files

| File | What to Configure |
|------|------------------|
| `inventory.ini` | Target host (localhost or remote IP) |
| `group_vars/keycloak.yml` | Mode selection, domain, redirect URIs |
| `group_vars/all.yml` | Passwords and secrets |

## Key Settings

### Deploy Mode vs External Mode

```yaml
# Deploy NEW Keycloak
keycloak_deploy_mode: true
keycloak_external_mode: false

# Use EXISTING Keycloak
keycloak_deploy_mode: false
keycloak_external_mode: true
```

### Important Variables

**Deploy Mode** (`group_vars/keycloak.yml`):
- `keycloak_host`: Your domain or IP.nip.io
- `keycloak_admin_password`: Master admin password

**External Mode** (`group_vars/keycloak.yml`):
- `keycloak_oidc_configuration_endpoint`: OIDC discovery URL

**Both Modes**:
- `keycloak_valid_redirect_uris`: NetBird domain URLs
- `keycloak_realm`: Realm name (default: "netbird")

## Security

### Encrypt Secrets
```bash
# Encrypt credentials
ansible-vault encrypt group_vars/all.yml

# Run with vault
ansible-playbook -i inventory.ini setup_and_run.yml --ask-vault-pass

# Edit encrypted file
ansible-vault edit group_vars/all.yml
```

### Generate Strong Passwords
```bash
openssl rand -base64 32
```

## Troubleshooting

### Collections not found
```bash
ansible-galaxy collection install -r requirements.yml --force
```

### Check deployment status
```bash
# Deploy mode - check containers
docker ps
docker logs keycloak

# Test OIDC endpoint
curl https://YOUR_DOMAIN/realms/netbird/.well-known/openid-configuration

# Verbose output
ansible-playbook -i inventory.ini setup_and_run.yml -vvv
```

### Docker not installed (Deploy Mode)
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in
```

## Re-running

The playbook is idempotent - safe to run multiple times:
```bash
ansible-playbook -i inventory.ini setup_and_run.yml
```

## Documentation

For detailed information, see:
- [`docs/KEYCLOAK_CONFIGURATION_GUIDE.md`](../docs/KEYCLOAK_CONFIGURATION_GUIDE.md) - Complete guide
- [`docs/KEYCLOAK_ARCHITECTURE.md`](../docs/KEYCLOAK_ARCHITECTURE.md) - Architecture details
- [`docs/Architecture.md`](../docs/Architecture.md) - NetBird architecture

## Next Steps

After deployment:
1. Note the OAuth client credentials from playbook output
2. Configure NetBird Management service with Keycloak endpoints
3. Configure NetBird Dashboard with OAuth credentials
4. Register your first NetBird peer
