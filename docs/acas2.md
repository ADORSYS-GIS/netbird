# 🛡️ Beginner-Friendly Manual Setup: NetBird + Keycloak Zero Trust

> ✅ For total beginners — no prior networking or security experience needed
> ⏱️ Time: ~60 minutes
> 📌 Prerequisites:
> - A working self-hosted NetBird (v0.25+)
> - A working self-hosted Keycloak (v20+)
> - Your own real domains (e.g., `netbird.internal`, `sso.yourorg.net`, or `keycloak.lab.local`)
>   ❌ Do NOT use `yourcompany.com` — it is for sale for $950,000 and not under your control!

---

## 🔑 Step 0: Prepare Your Real Domains (Critical!)

Before you begin, ensure you are using domains you own and control, such as:
- https://netbird.yourorg.net
- https://sso.yourorg.net

> 🔒 Why?
> If you use `yourcompany.com`, you'll be redirected to a domain sales page, not your services. This breaks SSO and creates security risks.

✅ In this guide, we'll use:
- NetBird URL: https://netbird.yourorg.net
- Keycloak URL: https://sso.yourorg.net

> 💡 Tip: For labs, use internal names like `netbird.local` with self-signed certs or a local CA.

---

## 🔐 Part 1: Enforce SSO with Keycloak (OIDC)

### Step 1.1: Create a Client in Keycloak

1. Open Keycloak Admin Console: https://sso.yourorg.net
2. Log in as admin.
3. Go to Clients → Create client
4. Choose OpenID Connect → Next
5. Set:
   - Client ID: `netbird`
   - Click Next
6. In Settings:
   - Client authentication: On
   - Authentication flow: Standard flow
   - Valid redirect URIs:
     ```
     https://netbird.yourorg.net/oidc/callback
     http://localhost:8080/oidc/callback
     ```
   - Web origins:
     ```
     https://netbird.yourorg.net
     ```
7. Click Save
8. Go to Credentials tab → Copy the Client secret

### Step 1.2: Configure NetBird to Use Keycloak

1. SSH into your NetBird management server:
   ```bash
   ssh admin@your-netbird-server
   ```
2. Edit the config file:
   ```bash
   sudo nano /etc/netbird/management.json
   ```
3. Add or update the `oidc_provider` section:
   ```json
   {
     "oidc_provider": {
       "issuer": "https://sso.yourorg.net/realms/master",
       "client_id": "netbird",
       "client_secret": "PASTE_YOUR_SECRET_HERE",
       "redirect_url": "https://netbird.yourorg.net/oidc/callback",
       "groups_claim": "groups"
     }
   }
   ```
4. Save (Ctrl+O → Enter → Ctrl+X)
5. Restart NetBird:
   ```bash
   sudo systemctl restart netbird-management
   ```
6. Test: Open https://netbird.yourorg.net in a browser → you should log in via Keycloak.
   - ✅ Success: Your user appears under Users in the NetBird UI.

---

## 🚫 Part 2: Implement Default-Deny ACLs (Zero Trust Baseline)

### Step 2.1: Create the Default-Deny Policy

- In NetBird UI → Access Control → Policies → Create Policy
- Name: Default-Deny
- Description: Blocks all traffic unless explicitly allowed
- Sources: Add source → All Users
- Destinations: Add destination → All Resources
- Action: Deny
- Enabled: ✅
- Click Create

### Step 2.2: Move It to the Bottom

- In the policy list, drag Default-Deny to the very bottom.
- ⚠️ NetBird applies rules top to bottom — this must be last!

Test from a client machine:
```bash
ping 100.x.y.z  # IP of another peer
```
It should time out — traffic is blocked by default.

---

## 🔒 Part 3: Define Least-Privilege Access Rules

### Step 3.1: Create Groups in Keycloak

- In Keycloak → Groups → Create group
- Create:
  - `engineering`
  - `support`
  - `db-admins`
- Assign users: Users → [select user] → Groups tab → Join group

### Step 3.2: Tag Your Servers in NetBird

In NetBird UI → Peers → for each server (not laptops!), click ⋯ → Edit and add tags:
- Web server (prod): `env:prod`, `role:web`
- MySQL server: `service:mysql`, `env:prod`
- Staging server: `env:staging`

### Step 3.3: Create Allow Rules (ABOVE Default-Deny!)

Rule 1: Engineers → SSH to Prod & Staging
- Name: Engineering-SSH
- Sources: Group `engineering`
- Destinations:
  - Tag `env:prod`, Port 22
  - Tag `env:staging`, Port 22
- Action: Allow

Rule 2: DB Admins → MySQL Only
- Name: DB-Admins-MySQL
- Sources: Group `db-admins`
- Destinations: Tag `service:mysql`, Port 3306
- Action: Allow

✅ Test:
- Engineer logs in → `ssh user@100.x.y.z` (prod server) → ✅ Works
- Support user tries same → ❌ Connection refused

---

## 🌐 Part 4: Split Tunneling + Per-Group DNS

### Step 4.1: Enable Split Tunneling

- In NetBird UI → Settings → Network
- Uncheck: Route all traffic through NetBird
- Click Save
- ✅ Result: Internet traffic (e.g., YouTube) uses your normal connection; only internal traffic uses NetBird.

### Step 4.2: Configure Group-Specific DNS

Add DNS servers:
- Settings → DNS → Nameservers → Add Nameserver
  - IP: `10.10.0.53` → Name: `eng-dns`
  - IP: `10.20.0.53` → Name: `support-dns`

Create DNS policies:
- Policy: Engineering-DNS
  - Sources: Group `engineering`
  - Nameservers: `eng-dns`
  - Search domains: `eng.internal`
- Policy: Support-DNS
  - Sources: Group `support`
  - Nameservers: `support-dns`
  - Search domains: `support.internal`

Test on client (macOS/Linux):
```bash
nslookup gitlab.eng.internal
# Should resolve using 10.10.0.53
```

---

## 🔁 Part 5: WireGuard Key Rotation

### Step 5.1: Understand Defaults

NetBird automatically:
- Rotates WireGuard keys every 180 days
- Disables inactive peers after 30 days

This is secure for most teams.

### Step 5.2: (Optional) Customize Rotation

Edit `/etc/netbird/management.json`:
```json
{
  "peer_login_expiration": 15768000,
  "peer_inactivity_timeout": 2592000
}
```
Values are seconds (180 days and 30 days).

Then restart:
```bash
sudo systemctl restart netbird-management
```

### Step 5.3: Manual Rotation (If Device Is Lost)

- In NetBird UI → Peers
- Find the device → Click ⋯ → Rotate Keys
- Device reconnects instantly with new keys
- ✅ Verify: Peer shows updated "Last connected" time

---

## ✅ Final Verification Checklist

| Test | Action | Expected Result |
|------|--------|-----------------|
| **SSO Login** | Visit https://netbird.yourorg.net | Redirected to Keycloak login |
| **Default-Deny** | `ping 100.x.y.z` from client | ❌ No response |
| **Engineer SSH** | `ssh user@prod-server` | ✅ Success |
| **Support SSH** | Same as above (as support user) | ❌ Permission denied |
| **Split Tunnel** | Visit https://whatismyip.com | Shows your real public IP |
| **DNS Resolution** | `nslookup jira.eng.internal` | Resolves via 10.10.0.53 |

---

## 🧼 Maintenance Best Practices

- **Monthly**: Audit Keycloak groups; remove inactive users
- **Quarterly**: Rotate Keycloak client secret
- **Always**: Back up `/etc/netbird/management.json`
- **Never**: Use placeholder domains like `yourcompany.com` — they are not yours!