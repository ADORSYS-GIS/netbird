# NetBird Complete Manual Configuration Guide

This guide provides detailed step-by-step instructions for manually configuring all five security requirements in NetBird.

## Table of Contents
1. [Default-Deny ACLs Configuration](#1-default-deny-acls-configuration)
2. [Granular Least-Privilege Access Rules](#2-granular-least-privilege-access-rules)
3. [Split Tunneling and DNS Configuration](#3-split-tunneling-and-dns-configuration)
4. [SSO/OIDC Authentication Setup](#4-ssooidc-authentication-setup)
5. [WireGuard Key Rotation Process](#5-wireguard-key-rotation-process)

---

## 1. Default-Deny ACLs Configuration

### Via Web Dashboard

1. **Login to NetBird Dashboard**
   ```
   https://app.netbird.io (for cloud)
   https://your-domain.com (for self-hosted)
   ```

2. **Navigate to Access Control**
   - Click on **"Access Control"** in the left sidebar
   - Click **"Rules"** tab

3. **Create Groups First**
   - Go to **"Groups"** section
   - Click **"Add Group"**
   - Create these groups:
     - `administrators` - For admin users
     - `web-servers` - For web server peers
     - `db-servers` - For database peers
     - `developers` - For developer workstations

4. **Create Allow Rules** (Order matters - specific rules first)
   
   **Rule 1: Admin Full Access**
   - Name: `Admin Full Access`
   - Sources: `administrators` group
   - Destinations: `All` 
   - Ports: Leave empty (all ports)
   - Protocol: `All`
   - Action: `Accept`
   - Bidirectional: `Yes`
   - Click **"Save"**

   **Rule 2: Web to Database**
   - Name: `Web to Database Access`
   - Sources: `web-servers` group
   - Destinations: `db-servers` group
   - Ports: `3306,5432,27017`
   - Protocol: `TCP`
   - Action: `Accept`
   - Bidirectional: `No`
   - Click **"Save"**

   **Rule 3: Developer SSH**
   - Name: `Developer SSH Access`
   - Sources: `developers` group
   - Destinations: `web-servers,db-servers` groups
   - Ports: `22`
   - Protocol: `TCP`
   - Action: `Accept`
   - Bidirectional: `No`
   - Click **"Save"**

5. **Create Default-Deny Rule** (Must be last!)
   - Name: `Default Deny All`
   - Sources: `All`
   - Destinations: `All`
   - Ports: Leave empty
   - Protocol: `All`
   - Action: `Drop`
   - Bidirectional: `Yes`
   - Click **"Save"**

### Via Management API

```bash
# Set your API token
export NETBIRD_TOKEN="your-api-token"
export API_URL="https://api.netbird.io"  # or your self-hosted URL

# Create groups
curl -X POST "$API_URL/api/groups" \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "administrators", "peers": []}'

curl -X POST "$API_URL/api/groups" \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "web-servers", "peers": []}'

# Create allow rules
curl -X POST "$API_URL/api/rules" \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Admin Full Access",
    "description": "Administrators have full network access",
    "enabled": true,
    "action": "accept",
    "sources": ["group:administrators"],
    "destinations": ["*"],
    "bidirectional": true
  }'

# Create default-deny rule (must be last)
curl -X POST "$API_URL/api/rules" \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Default Deny All",
    "description": "Deny all traffic not explicitly allowed",
    "enabled": true,
    "action": "drop",
    "sources": ["*"],
    "destinations": ["*"],
    "bidirectional": true
  }'
```

### Via Configuration File (Self-Hosted)

Edit `/etc/netbird/management.json`:

```json
{
  "Policy": {
    "Rules": [
      {
        "Name": "Admin Full Access",
        "Description": "Administrators have full network access",
        "Enabled": true,
        "Action": "accept",
        "Sources": ["group:administrators"],
        "Destinations": ["*"],
        "Bidirectional": true
      },
      {
        "Name": "Default Deny All",
        "Description": "Deny all traffic not explicitly allowed",
        "Enabled": true,
        "Action": "drop",
        "Sources": ["*"],
        "Destinations": ["*"],
        "Bidirectional": true
      }
    ]
  }
}
```

Restart management service:
```bash
systemctl restart netbird-management
```

---

## 2. Granular Least-Privilege Access Rules

### Service-Specific Rules

#### Web Dashboard Configuration

1. **Create Service Groups**
   - Navigate to **Groups**
   - Create groups for each service type:
     - `http-servers` - Web servers
     - `api-servers` - API endpoints
     - `monitoring` - Monitoring tools
     - `dns-servers` - DNS resolvers

2. **Define Port-Specific Rules**

   **HTTP/HTTPS Access**
   - Sources: `developers`
   - Destinations: `http-servers`
   - Ports: `80,443`
   - Protocol: `TCP`
   - Action: `Accept`

   **API Access**
   - Sources: `web-servers`
   - Destinations: `api-servers`
   - Ports: `8080,8443`
   - Protocol: `TCP`
   - Action: `Accept`

   **Monitoring Access**
   - Sources: `monitoring`
   - Destinations: `all-servers`
   - Ports: `9100,9090,3000`
   - Protocol: `TCP`
   - Action: `Accept`

### Tag-Based Rules

#### Setting Up Tags

1. **Via Dashboard**
   - Go to **Peers** section
   - Select a peer
   - Click **Edit**
   - Add tags in format: `key:value`
   - Examples:
     - `env:production`
     - `tier:database`
     - `team:engineering`

2. **Via API**
   ```bash
   curl -X PATCH "$API_URL/api/peers/{peer-id}" \
     -H "Authorization: Bearer $NETBIRD_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "tags": ["env:production", "tier:web", "team:platform"]
     }'
   ```

3. **Create Tag-Based Rules**
   ```bash
   curl -X POST "$API_URL/api/rules" \
     -H "Authorization: Bearer $NETBIRD_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Production Environment Isolation",
       "enabled": true,
       "action": "accept",
       "sources": ["tag:env:production"],
       "destinations": ["tag:env:production"],
       "description": "Isolate production from other environments"
     }'
   ```

---

## 3. Split Tunneling and DNS Configuration

### Split Tunneling Setup

#### Via Dashboard

1. **Navigate to Networks → Routes**

2. **Create Route for Internal Traffic**
   - Name: `Internal Services`
   - Network: `10.0.0.0/8`
   - Enabled: `Yes`
   - Peer Groups: Select groups that need access
   - Masquerade: `No` (for split tunnel)
   - Metric: `100`
   - Click **Save**

3. **Create Routes for Private Networks**
   ```
   Network: 192.168.0.0/16 - For office networks
   Network: 172.16.0.0/12 - For cloud resources
   Network: 10.0.0.0/8 - For internal services
   ```

#### Via CLI (on peer)

```bash
# Configure split tunneling on NetBird client
netbird up --allow-server-routes

# Check current routes
netbird status --detail

# Manually add custom routes (Linux/Mac)
sudo ip route add 10.0.0.0/8 dev wt0
sudo ip route add 192.168.0.0/16 dev wt0

# For Windows
netsh interface ipv4 add route 10.0.0.0/8 "NetBird"
```

### DNS Configuration

#### Global DNS Settings

1. **Via Dashboard**
   - Navigate to **DNS** section
   - Click **Settings**
   
2. **Configure Nameservers**
   - Primary: `8.8.8.8`
   - Secondary: `8.8.4.4`
   - Search Domains: `internal.company.com`
   
3. **Add Custom DNS Zones**
   - Domain: `*.internal`
   - Nameserver: `10.0.1.53`

#### Per-Group DNS Configuration

1. **Via API**
   ```bash
   # Configure DNS for production group
   curl -X POST "$API_URL/api/dns/nameservers" \
     -H "Authorization: Bearer $NETBIRD_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Production DNS",
       "description": "DNS servers for production environment",
       "enabled": true,
       "nameservers": [
         {"ip": "10.0.1.53", "port": 53},
         {"ip": "10.0.1.54", "port": 53}
       ],
       "groups": ["production-servers"],
       "primary": true
     }'
   ```

2. **Custom DNS Records**
   ```bash
   curl -X POST "$API_URL/api/dns/custom-zones" \
     -H "Authorization: Bearer $NETBIRD_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "domain": "services.internal",
       "records": [
         {"type": "A", "name": "database", "value": "10.0.2.10", "ttl": 300},
         {"type": "A", "name": "cache", "value": "10.0.2.20", "ttl": 300},
         {"type": "CNAME", "name": "api", "value": "api-lb.internal", "ttl": 300}
       ],
       "enabled": true,
       "groups": ["developers", "web-servers"]
     }'
   ```

---

## 4. SSO/OIDC Authentication Setup

### Keycloak Configuration

#### 1. Install Keycloak
```bash
docker run -d --name keycloak \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev
```

#### 2. Configure Keycloak Realm

1. **Access Keycloak Admin Console**
   - URL: `http://localhost:8080`
   - Login: `admin/admin`

2. **Create NetBird Realm**
   - Click **"Add Realm"**
   - Name: `netbird`
   - Click **Create**

3. **Create Client for NetBird Backend**
   - Go to **Clients** → **Create**
   - Client ID: `netbird-backend`
   - Client Protocol: `openid-connect`
   - Root URL: `https://netbird.example.com`
   
   **Settings:**
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://netbird.example.com/*`
   - Web Origins: `https://netbird.example.com`
   
   **Credentials:**
   - Copy the `Secret` value

4. **Create Client for Dashboard**
   - Client ID: `netbird-dashboard`
   - Access Type: `public`
   - Valid Redirect URIs: `https://netbird.example.com/*`

5. **Configure NetBird Management**

   Edit `.env` file:
   ```bash
   NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://keycloak.example.com/realms/netbird/.well-known/openid-configuration
   NETBIRD_AUTH_CLIENT_ID=netbird-backend
   NETBIRD_AUTH_CLIENT_SECRET=your-client-secret
   NETBIRD_AUTH_AUDIENCE=netbird-backend
   NETBIRD_USE_AUTH0=false
   NETBIRD_AUTH_SUPPORTED_SCOPES=openid profile email
   ```

### Auth0 Configuration

1. **Create Auth0 Application**
   - Type: `Regular Web Application`
   - Name: `NetBird`

2. **Configure Application**
   - Allowed Callback URLs: `https://netbird.example.com/callback`
   - Allowed Web Origins: `https://netbird.example.com`
   - Grant Types: Enable `Authorization Code` and `Refresh Token`

3. **Create API**
   - Name: `NetBird API`
   - Identifier: `https://netbird.example.com`

4. **Configure NetBird**
   ```bash
   NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://your-tenant.auth0.com/.well-known/openid-configuration
   NETBIRD_AUTH_CLIENT_ID=your-client-id
   NETBIRD_AUTH_CLIENT_SECRET=your-client-secret
   NETBIRD_AUTH_AUDIENCE=https://netbird.example.com
   NETBIRD_USE_AUTH0=true
   ```

### Okta Configuration

1. **Create Okta Application**
   - Sign in to Okta Admin Console
   - Applications → Create App Integration
   - Sign-in method: `OIDC`
   - Application type: `Web Application`

2. **Configure Application**
   - Sign-in redirect URIs: `https://netbird.example.com/callback`
   - Sign-out redirect URIs: `https://netbird.example.com/logout`
   - Grant type: `Authorization Code`, `Refresh Token`

3. **Configure NetBird**
   ```bash
   NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://your-domain.okta.com/.well-known/openid-configuration
   NETBIRD_AUTH_CLIENT_ID=your-client-id
   NETBIRD_AUTH_CLIENT_SECRET=your-client-secret
   NETBIRD_AUTH_AUDIENCE=api://default
   ```

### Azure AD Configuration

1. **Register Application**
   - Azure Portal → Azure Active Directory → App registrations
   - New registration
   - Name: `NetBird`
   - Redirect URI: `https://netbird.example.com/callback`

2. **Configure Application**
   - Authentication → Add platform → Web
   - Certificates & secrets → New client secret
   - API permissions → Add Microsoft Graph `User.Read`

3. **Configure NetBird**
   ```bash
   NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration
   NETBIRD_AUTH_CLIENT_ID=your-application-id
   NETBIRD_AUTH_CLIENT_SECRET=your-client-secret
   NETBIRD_AUTH_AUDIENCE=your-application-id
   ```

---

## 5. WireGuard Key Rotation Process

### Manual Key Rotation

#### Via Dashboard

1. **Navigate to Peers**
2. **Select peer to rotate**
3. **Click Actions → Rotate Key**
4. **Confirm rotation**

#### Via API

```bash
# Rotate single peer
curl -X POST "$API_URL/api/peers/{peer-id}/rotate-key" \
  -H "Authorization: Bearer $NETBIRD_TOKEN"

# Bulk rotation script
#!/bin/bash
PEERS=$(curl -s -H "Authorization: Bearer $NETBIRD_TOKEN" \
  "$API_URL/api/peers" | jq -r '.[].id')

for peer_id in $PEERS; do
  curl -X POST "$API_URL/api/peers/$peer_id/rotate-key" \
    -H "Authorization: Bearer $NETBIRD_TOKEN"
  echo "Rotated key for peer: $peer_id"
done
```

### Automated Key Rotation

#### Using Cron (Linux/Mac)

1. **Create rotation script** `/usr/local/bin/netbird-rotate.sh`:
   ```bash
   #!/bin/bash
   
   API_URL="https://api.netbird.io"
   TOKEN="your-api-token"
   LOG_FILE="/var/log/netbird-rotation.log"
   ROTATION_DAYS=30
   
   # Function to check and rotate keys
   rotate_old_keys() {
     peers=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/peers")
     
     echo "$peers" | jq -c '.[]' | while read peer; do
       peer_id=$(echo "$peer" | jq -r '.id')
       last_login=$(echo "$peer" | jq -r '.last_login')
       
       # Calculate days since last login
       days_old=$(( ($(date +%s) - $(date -d "$last_login" +%s)) / 86400 ))
       
       if [ $days_old -ge $ROTATION_DAYS ]; then
         echo "[$(date)] Rotating key for peer $peer_id (${days_old} days old)" >> $LOG_FILE
         curl -X POST "$API_URL/api/peers/$peer_id/rotate-key" \
           -H "Authorization: Bearer $TOKEN"
       fi
     done
   }
   
   rotate_old_keys
   ```

2. **Make executable**:
   ```bash
   chmod +x /usr/local/bin/netbird-rotate.sh
   ```

3. **Add to crontab**:
   ```bash
   crontab -e
   # Add line:
   0 2 * * 0 /usr/local/bin/netbird-rotate.sh
   ```

#### Using Systemd Timer (Linux)

1. **Create service** `/etc/systemd/system/netbird-rotate.service`:
   ```ini
   [Unit]
   Description=NetBird Key Rotation
   After=network.target
   
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/netbird-rotate.sh
   User=netbird
   Group=netbird
   StandardOutput=journal
   StandardError=journal
   
   [Install]
   WantedBy=multi-user.target
   ```

2. **Create timer** `/etc/systemd/system/netbird-rotate.timer`:
   ```ini
   [Unit]
   Description=NetBird Key Rotation Timer
   Requires=netbird-rotate.service
   
   [Timer]
   OnCalendar=weekly
   OnCalendar=Sun 02:00
   Persistent=true
   
   [Install]
   WantedBy=timers.target
   ```

3. **Enable timer**:
   ```bash
   systemctl daemon-reload
   systemctl enable netbird-rotate.timer
   systemctl start netbird-rotate.timer
   ```

#### Using Windows Task Scheduler

1. **Create PowerShell script** `C:\Scripts\NetBird-Rotate.ps1`:
   ```powershell
   $API_URL = "https://api.netbird.io"
   $TOKEN = "your-api-token"
   $LOG_FILE = "C:\Logs\netbird-rotation.log"
   
   $headers = @{
     "Authorization" = "Bearer $TOKEN"
   }
   
   # Get all peers
   $peers = Invoke-RestMethod -Uri "$API_URL/api/peers" -Headers $headers
   
   foreach ($peer in $peers) {
     $lastLogin = [DateTime]$peer.last_login
     $daysOld = (Get-Date) - $lastLogin
     
     if ($daysOld.Days -ge 30) {
       $message = "$(Get-Date) - Rotating key for peer $($peer.id)"
       Add-Content -Path $LOG_FILE -Value $message
       
       Invoke-RestMethod -Method POST `
         -Uri "$API_URL/api/peers/$($peer.id)/rotate-key" `
         -Headers $headers
     }
   }
   ```

2. **Create Scheduled Task**:
   - Open Task Scheduler
   - Create Basic Task
   - Name: `NetBird Key Rotation`
   - Trigger: Weekly, Sunday, 2:00 AM
   - Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File C:\Scripts\NetBird-Rotate.ps1`

### Key Rotation Best Practices

1. **Rotation Frequency**
   - Normal peers: Every 30 days
   - High-security peers: Every 7 days
   - Inactive peers: Immediately upon reactivation

2. **Backup Keys Before Rotation**
   ```bash
   # Backup script
   mkdir -p /backup/netbird/keys/$(date +%Y%m%d)
   
   for peer_id in $(netbird peers list | jq -r '.[].id'); do
     netbird peers show $peer_id > /backup/netbird/keys/$(date +%Y%m%d)/$peer_id.json
   done
   ```

3. **Monitor Rotation Status**
   ```bash
   # Check rotation logs
   tail -f /var/log/netbird-rotation.log
   
   # Alert on rotation failures
   if grep -q "ERROR" /var/log/netbird-rotation.log; then
     mail -s "NetBird Key Rotation Failed" admin@example.com < /var/log/netbird-rotation.log
   fi
   ```

---

## Verification Steps

### 1. Verify ACL Configuration
```bash
# List all rules
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/rules"

# Test connectivity between peers
netbird status --detail
ping <peer-ip>
```

### 2. Verify DNS Resolution
```bash
# Check DNS configuration
nslookup internal.service wt0
dig @10.0.1.53 database.internal

# Check split tunnel routes
ip route | grep wt0
```

### 3. Verify SSO Authentication
```bash
# Test OIDC endpoint
curl https://your-idp.com/.well-known/openid-configuration

# Check user authentication
netbird login
```

### 4. Verify Key Rotation
```bash
# Check key age
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/peers" | \
  jq '.[] | {id, name, key_update_timestamp}'

# Manual rotation test
curl -X POST -H "Authorization: Bearer $TOKEN" \
  "$API_URL/api/peers/{test-peer-id}/rotate-key"
```

---

## Troubleshooting

### Common Issues and Solutions

1. **ACL Rules Not Working**
   - Check rule order (specific rules before general)
   - Verify group membership
   - Check bidirectional settings
   - Review logs: `journalctl -u netbird`

2. **DNS Not Resolving**
   - Verify DNS server connectivity
   - Check nameserver configuration
   - Test with: `nslookup -debug`
   - Check peer DNS settings: `netbird status --detail`

3. **SSO Authentication Failures**
   - Verify OIDC endpoint accessibility
   - Check client ID/secret
   - Review redirect URLs
   - Check token expiration
   - Logs: `docker logs netbird-management`

4. **Key Rotation Failures**
   - Verify API token validity
   - Check peer connectivity
   - Review rotation script logs
   - Ensure proper permissions
   - Test manual rotation first

5. **Split Tunneling Issues**
   - Verify route configuration
   - Check routing table: `ip route`
   - Ensure allow-server-routes is enabled
   - Check for route conflicts

---

## Security Checklist

- [ ] Default-deny rule is the last rule in ACL list
- [ ] All groups have appropriate access rules defined
- [ ] Service-specific ports are explicitly defined
- [ ] SSO/OIDC is enforced for all users
- [ ] MFA is enabled on the IdP
- [ ] Key rotation is automated and monitored
- [ ] DNS servers are secure and monitored
- [ ] Split tunneling excludes internet traffic
- [ ] Audit logs are enabled and reviewed
- [ ] Backup procedures are in place
- [ ] Emergency access procedures documented
- [ ] Regular security audits scheduled

---

## Additional Resources

- [NetBird Documentation](https://docs.netbird.io)
- [NetBird API Reference](https://docs.netbird.io/api)
- [WireGuard Protocol](https://www.wireguard.com/protocol/)
- [OIDC Specifications](https://openid.net/connect/)
- [Zero Trust Architecture](https://www.nist.gov/publications/zero-trust-architecture)