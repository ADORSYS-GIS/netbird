# Keycloak Configuration Guide

Complete guide for configuring NetBird with Keycloak in both **Deploy Mode** (new Keycloak instance) and **External Mode** (existing Keycloak instance).

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Mode Selection](#mode-selection)
3. [Deploy Mode Configuration](#deploy-mode-configuration)
4. [External Mode Configuration](#external-mode-configuration)
5. [Vault Configuration (Secrets)](#vault-configuration-secrets)
6. [Common Configuration](#common-configuration)
7. [Pre-Deployment Checklist](#pre-deployment-checklist)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Keycloak role supports two deployment modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Deploy Mode** | Deploys a NEW Keycloak instance with PostgreSQL and Caddy | Testing, development, or standalone deployments |
| **External Mode** | Connects to an EXISTING Keycloak instance | Enterprise environments with centralized identity management |

### What Gets Deployed

**Deploy Mode deploys:**
- Keycloak 22.0 server
- PostgreSQL 15 database
- Caddy reverse proxy (HTTPS with automatic certificates)
- NetBird realm with OAuth clients

**External Mode configures:**
- OAuth clients in existing Keycloak realm
- NetBird integration with existing identity provider
- No infrastructure deployment

---

## Mode Selection

Edit `deploy/group_vars/keycloak.yml` and set **exactly ONE mode to true**:

```yaml
# Choose ONE mode only:
keycloak_deploy_mode: true   # Deploy NEW Keycloak
keycloak_external_mode: false # Use EXISTING Keycloak
```

Or for external mode:

```yaml
keycloak_deploy_mode: false  # Deploy NEW Keycloak
keycloak_external_mode: true # Use EXISTING Keycloak
```

⚠️ **Important:** Both modes cannot be true simultaneously. The playbook will fail validation if both are enabled.

---

## Deploy Mode Configuration

### 📂 Files to Configure

1. **`deploy/group_vars/keycloak.yml`** - Main configuration
2. **`deploy/group_vars/vault.yml`** - Sensitive secrets (encrypted with Ansible Vault)

### Step-by-Step Configuration

#### Step 1: Enable Deploy Mode

Edit `deploy/group_vars/keycloak.yml`:

```yaml
keycloak_deploy_mode: true
keycloak_external_mode: false
```

#### Step 2: Configure Keycloak Host Domain

**Line 26** in `keycloak.yml`:

```yaml
# Replace with your domain or IP address
keycloak_host: "10.165.218.128.nip.io"  # Example using nip.io
# OR
keycloak_host: "keycloak.yourcompany.com"  # Example with real domain
```

**Options:**
- Use **nip.io** for automatic DNS: `YOUR_IP.nip.io` (e.g., `10.165.218.128.nip.io`)
- Use a **real domain** if you have one configured in DNS
- Use **localhost** for local testing only

#### Step 3: Configure Administrator Credentials

**Lines 32-33** in `keycloak.yml`:

```yaml
keycloak_admin_user: "admin"
keycloak_admin_password: "{{ vault_keycloak_admin_password }}"
```

**DO NOT hardcode passwords here!** Set them in vault.yml (see [Vault Configuration](#vault-configuration-secrets)).

#### Step 4: Configure Database Password

**Line 36** in `keycloak.yml`:

```yaml
keycloak_db_password: "{{ vault_keycloak_db_password }}"
```

Again, the actual password goes in `vault.yml`.

#### Step 5: Configure Redirect URIs

**Lines 71-74** in `keycloak.yml`:

```yaml
keycloak_valid_redirect_uris:
  - "https://netbird.yourcompany.com/*"  # ⚠️ REPLACE THIS!
  - "http://localhost:53000"              # NetBird CLI local callback
```

⚠️ **CRITICAL:** Replace `netbird.yourcompany.com` with your actual NetBird domain or IP address!

**Examples:**
```yaml
# For AWS domain:
  - "https://netbird.aws.yourcompany.com/*"

# For IP address with nip.io:
  - "https://192.168.1.100.nip.io/*"

# For localhost testing:
  - "http://localhost:8081/*"
```

#### Step 6: Set Vault Passwords

Edit `deploy/group_vars/vault.yml` and add:

```yaml
vault_keycloak_admin_password: "YourStrongAdminPassword123!"
vault_keycloak_db_password: "YourStrongDatabasePassword456!"
```

**Encrypt the vault file:**
```bash
ansible-vault encrypt deploy/group_vars/vault.yml
```

### Deploy Mode Summary

| Configuration Item | File | Line | What to Replace |
|-------------------|------|------|-----------------|
| **Mode Selection** | keycloak.yml | 12-13 | Set `keycloak_deploy_mode: true` |
| **Domain/Host** | keycloak.yml | 26 | Replace `localhost` with your domain |
| **Admin Password** | vault.yml | - | Add `vault_keycloak_admin_password` |
| **DB Password** | vault.yml | - | Add `vault_keycloak_db_password` |
| **Redirect URIs** | keycloak.yml | 71-74 | Replace placeholder domains |

### What Happens During Deployment

1. ✅ Installs Docker and Docker Compose (if not present)
2. ✅ Creates `/opt/keycloak` directory
3. ✅ Deploys PostgreSQL 15 database
4. ✅ Deploys Keycloak 22.0 server
5. ✅ Deploys Caddy reverse proxy (ports 80, 443)
6. ✅ Creates NetBird realm
7. ✅ Creates OAuth clients: `netbird-client` and `netbird-backend`
8. ✅ Configures OIDC endpoints
9. ✅ Exports configuration to `netbird-external-config.env`

### Access URLs (Deploy Mode)

After successful deployment:

- **Keycloak Console:** `https://YOUR_HOST/admin`
- **NetBird Realm:** `https://YOUR_HOST/realms/netbird`
- **OIDC Endpoint:** `https://YOUR_HOST/realms/netbird/.well-known/openid-configuration`

---

## External Mode Configuration

### 📂 Files to Configure

1. **`deploy/group_vars/keycloak.yml`** - Main configuration
2. **`deploy/group_vars/vault.yml`** - Sensitive secrets
3. **`deploy/group_vars/all.yml`** - Backend client secret (if using vault reference)

### Prerequisites

Before configuring external mode, ensure your boss/admin has:

1. ✅ Created a Keycloak realm (e.g., `netbird`)
2. ✅ Created service account client: `netbird-backend` with:
   - Service Accounts Enabled: **ON**
   - Authorization Enabled: **ON**
   - Valid Redirect URIs configured
3. ✅ Provided you with the **client secret** for `netbird-backend`

### Step-by-Step Configuration

#### Step 1: Enable External Mode

Edit `deploy/group_vars/keycloak.yml`:

```yaml
keycloak_deploy_mode: false
keycloak_external_mode: true
```

#### Step 2: Configure OIDC Endpoint

**Line 47** in `keycloak.yml`:

```yaml
keycloak_oidc_configuration_endpoint: "https://your_keycloak_domain.team/realms/netbird/.well-known/openid-configuration"
```

**How to get this:**

1. Ask your Keycloak administrator for the realm name
2. Format: `https://YOUR_KEYCLOAK_HOST/realms/YOUR_REALM/.well-known/openid-configuration`

**Example:**
```yaml
# For boss's Keycloak at your_keycloak_domain.team with realm "netbird":
keycloak_oidc_configuration_endpoint: "https://your_keycloak_domain.team/realms/netbird/.well-known/openid-configuration"

# For company Keycloak at auth.company.com with realm "production":
keycloak_oidc_configuration_endpoint: "https://auth.company.com/realms/production/.well-known/openid-configuration"
```

#### Step 3: Configure Realm Admin Credentials

**Lines 50-51** in `keycloak.yml`:

```yaml
keycloak_realm_admin_user: "{{ vault_keycloak_realm_admin_user | default('netbird-backend') }}"
keycloak_realm_admin_password: "{{ vault_keycloak_realm_admin_password | default(vault_netbird_backend_client_secret) }}"
```

**Usually you don't need to change these** as they default to using the backend client credentials.

#### Step 4: Set Backend Client Secret

**Option A: Direct in vault.yml (Recommended)**

Edit `deploy/group_vars/vault.yml`:

```yaml
vault_netbird_backend_client_secret: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

Replace with the **actual client secret** provided by your Keycloak administrator.

**Option B: In all.yml (then reference in vault)**

Edit `deploy/group_vars/all.yml`:

```yaml
vault_netbird_backend_client_secret: "YOUR_CLIENT_SECRET_FROM_BOSS"
```

Replace `YOUR_CLIENT_SECRET_FROM_BOSS` with the real secret.

**How to get the client secret:**

Ask your Keycloak admin, or if you have admin access:

1. Log into Keycloak admin console
2. Navigate to: Clients → `netbird-backend`
3. Go to **Credentials** tab
4. Copy the **Client Secret** value

#### Step 5: Configure SSL Certificate Validation

**Line 54** in `keycloak.yml`:

```yaml
keycloak_validate_certs: true
```

Set to `false` only if your Keycloak uses self-signed certificates (NOT recommended for production):

```yaml
keycloak_validate_certs: false  # Only for testing!
```

#### Step 6: Configure Redirect URIs

**Lines 71-74** in `keycloak.yml`:

```yaml
keycloak_valid_redirect_uris:
  - "https://netbird.yourcompany.com/*"      # ⚠️ REPLACE THIS!
  - "https://your_keycloak_domain.team/*"     # Your Keycloak SSO origin
  - "http://localhost:53000"                 # NetBird CLI local callback
```

**Important:** Include BOTH your NetBird domain AND your Keycloak domain.

**Examples:**
```yaml
keycloak_valid_redirect_uris:
  - "https://netbird.aws.company.com/*"      # Your NetBird deployment
  - "https://auth.company.com/*"             # Your Keycloak server
  - "http://localhost:53000"                 # CLI callback
```

#### Step 7: Encrypt Vault File

```bash
ansible-vault encrypt deploy/group_vars/vault.yml
```

### External Mode Summary

| Configuration Item | File | Line | What to Replace |
|-------------------|------|------|-----------------|
| **Mode Selection** | keycloak.yml | 12-13 | Set `keycloak_external_mode: true` |
| **OIDC Endpoint** | keycloak.yml | 47 | Replace with your Keycloak's OIDC URL |
| **Client Secret** | vault.yml | - | Add `vault_netbird_backend_client_secret` |
| **Redirect URIs** | keycloak.yml | 71-74 | Add your NetBird and Keycloak domains |
| **SSL Validation** | keycloak.yml | 54 | `true` for prod, `false` for self-signed |

### What Happens During Configuration

1. ✅ Validates OIDC endpoint accessibility
2. ✅ Extracts Keycloak base URL and realm name automatically
3. ✅ Creates/updates `netbird-client` OAuth client in existing realm
4. ✅ Creates/updates `netbird-backend` service account client
5. ✅ Configures proper redirect URIs and CORS settings
6. ✅ Exports configuration to `netbird-external-config.env`

### Access URLs (External Mode)

Use the existing Keycloak URLs provided by your administrator:

- **Keycloak Console:** Provided by admin
- **NetBird Realm:** `https://YOUR_KEYCLOAK_HOST/realms/YOUR_REALM`
- **OIDC Endpoint:** (As configured in line 47)

---

## Vault Configuration (Secrets)

### What is Ansible Vault?

Ansible Vault encrypts sensitive data like passwords and secrets. Never commit unencrypted secrets to Git!

### Creating/Editing Vault File

**Create new vault:**
```bash
ansible-vault create deploy/group_vars/vault.yml
```

**Edit existing vault:**
```bash
ansible-vault edit deploy/group_vars/vault.yml
```

**Encrypt existing file:**
```bash
ansible-vault encrypt deploy/group_vars/vault.yml
```

### Vault Variables Required

#### For Deploy Mode

```yaml
# In deploy/group_vars/vault.yml
vault_keycloak_admin_password: "YourStrongAdminPassword123!"
vault_keycloak_db_password: "YourStrongDatabasePassword456!"
```

#### For External Mode

```yaml
# In deploy/group_vars/vault.yml
vault_netbird_backend_client_secret: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

# Optional (defaults to backend client):
vault_keycloak_realm_admin_user: "netbird-backend"
vault_keycloak_realm_admin_password: "same-as-client-secret"
```

#### For Both Modes

```yaml
# Optional: If you want to set specific realm admin credentials
vault_keycloak_realm_admin_user: "realm-admin"
vault_keycloak_realm_admin_password: "SecureRealmPassword789!"
```

### Password Requirements

- **Minimum length:** 12 characters
- **Include:** Uppercase, lowercase, numbers, special characters
- **Avoid:** Dictionary words, common patterns
- **Use:** Password manager to generate secure passwords

### Running Playbook with Vault

```bash
# Prompt for vault password:
ansible-playbook -i inventory.ini setup_and_run.yml --ask-vault-pass

# Use password file:
ansible-playbook -i inventory.ini setup_and_run.yml --vault-password-file ~/.vault_pass

# Use environment variable:
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook -i inventory.ini setup_and_run.yml
```

---

## Common Configuration

These settings apply to **BOTH** deploy and external modes.

### Realm Configuration

**Line 62** in `keycloak.yml`:

```yaml
keycloak_realm: "netbird"
```

Change this if your realm has a different name (for external mode, ensure it matches the realm in OIDC endpoint).

### OAuth Client Names

**Lines 65-66** in `keycloak.yml`:

```yaml
keycloak_client_netbird: "netbird-client"          # Public client (Dashboard/CLI)
keycloak_client_netbird_backend: "netbird-backend"  # Service account (Management API)
```

**Usually don't change these** unless you have specific naming requirements.

### Redirect URIs

**Lines 71-74** in `keycloak.yml`:

```yaml
keycloak_valid_redirect_uris:
  - "https://YOUR_NETBIRD_DOMAIN/*"   # ⚠️ REPLACE THIS!
  - "http://localhost:53000"           # CLI local callback
```

**Must include:**
- Your NetBird dashboard URL with wildcard: `https://netbird.company.com/*`
- CLI callback: `http://localhost:53000`
- (External mode) Your Keycloak origin: `https://auth.company.com/*`

### Web Origins (CORS)

**Line 77** in `keycloak.yml`:

```yaml
keycloak_web_origins: "+"  # Allows all origins
```

**For production**, restrict to specific domains:

```yaml
keycloak_web_origins:
  - "https://netbird.company.com"
  - "https://auth.company.com"
```

---

## Pre-Deployment Checklist

### Deploy Mode Checklist

- [ ] Set `keycloak_deploy_mode: true` and `keycloak_external_mode: false`
- [ ] Configure `keycloak_host` with your domain or IP
- [ ] Set `vault_keycloak_admin_password` in vault.yml
- [ ] Set `vault_keycloak_db_password` in vault.yml
- [ ] Replace placeholder redirect URIs with actual NetBird domains
- [ ] Encrypt vault.yml with `ansible-vault encrypt`
- [ ] Ensure ports 80, 443, and 8080 are available
- [ ] Verify Docker and Docker Compose are installed (or will be installed)

### External Mode Checklist

- [ ] Set `keycloak_deploy_mode: false` and `keycloak_external_mode: true`
- [ ] Get OIDC configuration endpoint from admin
- [ ] Configure `keycloak_oidc_configuration_endpoint`
- [ ] Get `netbird-backend` client secret from admin
- [ ] Set `vault_netbird_backend_client_secret` in vault.yml
- [ ] Add both NetBird AND Keycloak domains to redirect URIs
- [ ] Set `keycloak_validate_certs` appropriately
- [ ] Encrypt vault.yml with `ansible-vault encrypt`
- [ ] Verify network connectivity to external Keycloak server
- [ ] Confirm service account has proper permissions in Keycloak

---

## Troubleshooting

### Common Issues

#### ❌ "Exactly one mode must be true"

**Problem:** Both modes are enabled or both are disabled.

**Solution:** Set exactly ONE mode to `true`:

```yaml
# Deploy Mode:
keycloak_deploy_mode: true
keycloak_external_mode: false

# OR External Mode:
keycloak_deploy_mode: false
keycloak_external_mode: true
```

#### ❌ "Required deployment mode variables are missing"

**Problem:** Deploy mode is enabled but passwords are not set.

**Solution:** Add to vault.yml:

```yaml
vault_keycloak_admin_password: "YourPassword"
vault_keycloak_db_password: "YourPassword"
```

#### ❌ "keycloak_oidc_configuration_endpoint is required for external mode"

**Problem:** External mode is enabled but OIDC endpoint is not configured.

**Solution:** Set the OIDC endpoint in keycloak.yml line 47:

```yaml
keycloak_oidc_configuration_endpoint: "https://your-keycloak-host/realms/your-realm/.well-known/openid-configuration"
```

#### ❌ "YOUR_CLIENT_SECRET_FROM_BOSS"

**Problem:** Client secret placeholder not replaced.

**Solution:** Replace with actual secret in vault.yml:

```yaml
vault_netbird_backend_client_secret: "actual-secret-from-admin"
```

#### ❌ "Redirect URIs not configured"

**Problem:** Placeholder `YOUR_NETBIRD_DOMAIN` found in configuration.

**Solution:** Replace in keycloak.yml line 72:

```yaml
keycloak_valid_redirect_uris:
  - "https://netbird.actualcompany.com/*"  # Real domain
```

#### ❌ Port 80 or 443 already in use (Deploy Mode)

**Problem:** Another service (Nginx, Apache) is using ports 80 or 443.

**Solution:** Stop the conflicting service:

```bash
# Check what's using ports:
sudo ss -tulpn | grep ':80\|:443'

# Stop conflicting service (example with Nginx):
sudo systemctl stop nginx
sudo systemctl disable nginx
```

#### ❌ SSL certificate validation fails (External Mode)

**Problem:** External Keycloak uses self-signed certificates.

**Solution:** Set in keycloak.yml:

```yaml
keycloak_validate_certs: false  # Only for testing!
```

**Better solution:** Get proper SSL certificates for your Keycloak server.

#### ❌ Cannot connect to external Keycloak

**Problem:** Network connectivity or firewall issues.

**Solution:**

1. Test connectivity:
   ```bash
   curl -v https://your-keycloak-host/realms/your-realm/.well-known/openid-configuration
   ```

2. Check firewall rules
3. Verify Keycloak is running
4. Confirm OIDC endpoint URL is correct

### Validation Commands

**Check configuration:**
```bash
ansible-playbook -i inventory.ini setup_and_run.yml --syntax-check
```

**Test connectivity to external Keycloak:**
```bash
curl -v https://your-keycloak-host/realms/your-realm/.well-known/openid-configuration
```

**View vault contents:**
```bash
ansible-vault view deploy/group_vars/vault.yml
```

**Check deployed services (Deploy Mode):**
```bash
docker ps
docker compose -f /opt/keycloak/docker-compose.yml ps
```

---

## Getting Help

### Log Files

**Deploy Mode:**
```bash
# Keycloak logs:
docker logs netbird-keycloak

# PostgreSQL logs:
docker logs keycloak_postgres

# Caddy logs:
docker logs caddy
```

**Ansible verbose output:**
```bash
ansible-playbook -i inventory.ini setup_and_run.yml -vvv --ask-vault-pass
```

### Useful Commands

**Check Keycloak health (Deploy Mode):**
```bash
curl -v http://localhost:8080/health/ready
```

**Test HTTPS access (Deploy Mode):**
```bash
curl -k https://your-host/realms/netbird/.well-known/openid-configuration
```

**Check generated NetBird configuration:**
```bash
cat deploy/netbird-external-config.env
```

---

## Summary

| Feature | Deploy Mode | External Mode |
|---------|-------------|---------------|
| **Deploys Keycloak** | ✅ Yes | ❌ No |
| **Deploys PostgreSQL** | ✅ Yes | ❌ No |
| **Deploys Caddy** | ✅ Yes | ❌ No |
| **Creates Realm** | ✅ Yes | ❌ No (uses existing) |
| **Creates Clients** | ✅ Yes | ✅ Yes |
| **Requires Admin Access** | ✅ Yes (creates admin) | ⚠️ Limited (service account) |
| **Best For** | Testing, standalone | Enterprise, centralized auth |

---

**Ready to deploy?** Follow the checklist for your chosen mode, then run:

```bash
ansible-playbook -i deploy/inventory.ini deploy/setup_and_run.yml --ask-vault-pass
```

Good luck! 🚀
