# NetBird IDP Setup Scripts

This directory contains scripts to configure Identity Providers for NetBird.

## Scripts

### 1. `zitadel-setup.sh` - Complete Zitadel Bootstrap

Bootstraps a complete testing environment including NetBird services, Zitadel IDP, and PostgreSQL.

**Prerequisites**: Docker, Docker Compose, `jq`, `curl`

**Usage:**
```bash
# Local/Testing Environment
export NETBIRD_DISABLE_LETSENCRYPT=true
export NETBIRD_DOMAIN="YOUR_IP_ADDRESS" # e.g., 192.168.1.100

chmod +x infrastructure/scripts/zitadel-setup.sh
./infrastructure/scripts/zitadel-setup.sh
```

**Access:**
- Dashboard: `http://<NETBIRD_DOMAIN>`
- Credentials output to console

**Troubleshooting "Insecure Origin":**
For local HTTP testing, some browsers block authentication. Workaround:
1. Open `chrome://flags`
2. Search for "Insecure origins treated as secure"
3. Add your URL (e.g., `http://192.168.1.100`)
4. Relaunch browser

---

### 2. `keycloak-setup.sh` - Configure Existing Keycloak

Configures an existing Keycloak instance for NetBird integration. Creates realm, clients, and generates secrets.

**Prerequisites**: `curl`, `jq`
```bash
# Install dependencies
sudo apt install jq curl # Debian/Ubuntu
brew install jq curl    # macOS
```

**Usage:**
```bash
# Manual Configuration
KEYCLOAK_URL=https://keycloak.example.com \
KEYCLOAK_ADMIN_PASSWORD=your-admin-password \
NETBIRD_DOMAIN=netbird.example.com \
NETBIRD_REALM=netbird \
./infrastructure/scripts/keycloak-setup.sh
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `KEYCLOAK_URL` | (Required) | Full URL to Keycloak (e.g., https://idp.example.com) |
| `KEYCLOAK_ADMIN_USER` | `admin` | Keycloak admin username |
| `KEYCLOAK_ADMIN_PASSWORD` | (Required) | Keycloak admin password |
| `NETBIRD_DOMAIN` | (Required) | Your NetBird instance domain |
| `NETBIRD_REALM` | `netbird` | Name of the realm to create/configure |
| `NETBIRD_DEFAULT_USER` | `admin` | Initial dashboard user to create |
| `NETBIRD_DEFAULT_PASSWORD` | (Optional) | Initial dashboard user password |
| `OUTPUT_FORMAT` | `text` | Set to `json` for machine-readable output |

**What it does:**
1. Authenticates to Keycloak admin API
2. Creates NetBird realm
3. Configures `netbird-client` (public OAuth client for web/dashboard)
4. Configures `netbird-management` (service account for management API)
5. Generates random secrets for NetBird services
6. Outputs configuration for Ansible `vars.yml`

**Output:**
- Client IDs and secrets
- Generated NetBird service secrets
- Ready-to-use Ansible configuration

**CI/CD Usage:**
The script supports JSON output for automation:
```bash
OUTPUT_FORMAT=json ./infrastructure/scripts/keycloak-setup.sh
```

This is automatically used by GitHub Actions workflow when Keycloak secrets are provided.


---
