# NetBird Quickstart Script

This script bootstraps a complete testing environment including NetBird services (Management, Signal, Relay, Dashboard), a Zitadel Identity Provider, and PostgreSQL.

**Prerequisites**: Docker, Docker Compose, `jq`, `curl`.

## Usage

Execute the script to provision the stack. For local testing, disable Let's Encrypt and bind to your IP address.

```bash
# Local/Testing Environment
export NETBIRD_DISABLE_LETSENCRYPT=true
export NETBIRD_DOMAIN="YOUR_IP_ADDRESS" # e.g., 192.168.1.100

chmod +x infrastructure/scripts/zitadel-setup.sh
./infrastructure/scripts/zitadel-setup.sh
```

## Access

- **Dashboard**: `http://<NETBIRD_DOMAIN>`
- **Credentials**: Admin username and password are output to the console upon completion.

### Troubleshooting "Insecure Origin"

If you are running this locally with `NETBIRD_DISABLE_LETSENCRYPT=true` (HTTP), some browsers (like Chrome/Brave) may block the authentication flow because the OIDC origin is insecure.

**Workaround (Test Only):**
1.  Open `chrome://flags` in your browser.
2.  Search for "Insecure origins treated as secure".
3.  Enable it and add your URL (e.g., `http://192.168.1.100`) to the list.
4.  Relaunch the browser.
