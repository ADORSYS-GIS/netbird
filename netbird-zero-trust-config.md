# NetBird Management Server Zero-Trust Configuration Guide

## 1. Default-Deny ACLs Configuration

NetBird supports default-deny through its ACL system. Configure via the Management API or Dashboard:

### Via Management API:
```bash
# Create default-deny rule (should be the last rule)
curl -X POST https://api.netbird.io/api/rules \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Default Deny All",
    "description": "Deny all traffic by default",
    "enabled": true,
    "action": "drop",
    "sources": ["*"],
    "destinations": ["*"],
    "bidirectional": true,
    "priority": 9999
  }'
```

### Via Dashboard UI:
1. Navigate to **Access Control** → **Rules**
2. Create a new rule at the bottom of the list
3. Set Action: **Drop**
4. Set Sources: **All peers**
5. Set Destinations: **All peers**

## 2. Granular Least-Privilege Access Rules

### Create Groups First:
```bash
# Create service groups
curl -X POST https://api.netbird.io/api/groups \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{"name": "web-servers", "peers": []}'

curl -X POST https://api.netbird.io/api/groups \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{"name": "databases", "peers": []}'

curl -X POST https://api.netbird.io/api/groups \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{"name": "admin-users", "peers": []}'
```

### Create Specific Access Rules:
```bash
# Allow web servers to access databases on specific ports
curl -X POST https://api.netbird.io/api/rules \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{
    "name": "Web to Database Access",
    "description": "Allow web servers to connect to database servers",
    "enabled": true,
    "action": "accept",
    "sources": ["group:web-servers"],
    "destinations": ["group:databases"],
    "ports": ["5432/tcp", "3306/tcp"],
    "bidirectional": false,
    "priority": 100
  }'

# Allow admins full access
curl -X POST https://api.netbird.io/api/rules \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{
    "name": "Admin Full Access",
    "enabled": true,
    "action": "accept",
    "sources": ["group:admin-users"],
    "destinations": ["*"],
    "bidirectional": true,
    "priority": 10
  }'
```

## 3. Split Tunneling and Per-Group DNS Settings

### Configure Routes (Split Tunneling):
```bash
# Create network route for specific subnets only
curl -X POST https://api.netbird.io/api/routes \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{
    "description": "Internal services subnet",
    "network": "10.100.0.0/24",
    "enabled": true,
    "peer_groups": ["web-servers"],
    "masquerade": false,
    "metric": 9999,
    "groups": ["web-servers"]
  }'
```

### Configure DNS Settings per Group:
```bash
# Set custom nameservers for specific groups
curl -X POST https://api.netbird.io/api/dns/nameservers \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{
    "name": "Internal DNS",
    "description": "Internal DNS for production servers",
    "enabled": true,
    "nameservers": [
      {"ip": "10.100.1.53", "port": 53},
      {"ip": "10.100.1.54", "port": 53}
    ],
    "groups": ["web-servers", "databases"],
    "primary": true
  }'

# Configure DNS zones
curl -X POST https://api.netbird.io/api/dns/settings \
  -H "Authorization: Bearer $NETBIRD_TOKEN" \
  -d '{
    "disabled_management_groups": [],
    "custom_zones": [
      {
        "domain": "internal.company.com",
        "nameservers": ["10.100.1.53"],
        "groups": ["web-servers", "databases"]
      }
    ]
  }'
```

## 4. SSO/OIDC Configuration

### For Self-Hosted NetBird:
Edit your `management.json` configuration:

```json
{
  "HttpConfig": {
    "Address": "0.0.0.0:80",
    "AuthIssuer": "https://your-oidc-provider.com",
    "AuthClientId": "your-client-id",
    "AuthClientSecret": "your-client-secret",
    "AuthAudience": "your-audience",
    "AuthKeysLocation": "https://your-oidc-provider.com/.well-known/jwks.json"
  },
  "IdpManagerConfig": {
    "ManagerType": "oidc",
    "ClientConfig": {
      "Issuer": "https://your-oidc-provider.com",
      "TokenEndpoint": "https://your-oidc-provider.com/oauth/token",
      "ClientID": "your-client-id",
      "ClientSecret": "your-client-secret",
      "GrantType": "client_credentials"
    }
  }
}
```

### Supported OIDC Providers:
- **Keycloak**: Full support with auto-discovery
- **Auth0**: Built-in integration
- **Okta**: Native support
- **Azure AD**: Full Microsoft identity platform
- **Google Workspace**: Direct integration
- **Generic OIDC**: Any OIDC-compliant provider

### Example with Keycloak:
```bash
# Set environment variables for Docker deployment
cat > .env << EOF
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://keycloak.company.com/realms/netbird/.well-known/openid-configuration
NETBIRD_AUTH_AUDIENCE=netbird-client
NETBIRD_USE_AUTH0=false
NETBIRD_AUTH_CLIENT_ID=netbird-backend
NETBIRD_AUTH_CLIENT_SECRET=your-secret-here
NETBIRD_AUTH_SUPPORTED_SCOPES=openid profile email
NETBIRD_AUTH_DEVICE_AUTH_PROVIDER=hosted
EOF
```

## 5. WireGuard Key Rotation

### Automatic Key Rotation (Built-in):
NetBird automatically rotates keys. Configure the interval:

```bash
# In management.json for self-hosted
{
  "PeerConfig": {
    "LoginExpirationEnabled": true,
    "LoginExpiration": "720h",  # 30 days
    "KeyRotationEnabled": true,
    "KeyRotationInterval": "168h"  # 7 days
  }
}
```

### Manual Key Rotation via API:
```bash
# Force key rotation for a specific peer
curl -X POST https://api.netbird.io/api/peers/{peer_id}/rotate-key \
  -H "Authorization: Bearer $NETBIRD_TOKEN"

# Bulk rotation for a group
curl -X POST https://api.netbird.io/api/groups/{group_id}/rotate-keys \
  -H "Authorization: Bearer $NETBIRD_TOKEN"
```

### Automated Key Rotation Script:
```bash
#!/bin/bash
# rotate-keys.sh - Run via cron for regular rotation

NETBIRD_API="https://api.netbird.io"
TOKEN="your-management-token"

# Get all peers
peers=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$NETBIRD_API/api/peers" | jq -r '.[].id')

# Rotate keys for peers older than 30 days
for peer_id in $peers; do
  last_seen=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$NETBIRD_API/api/peers/$peer_id" | jq -r '.last_seen')
  
  # Check if key is older than 30 days
  if [[ $(date -d "$last_seen" +%s) -lt $(date -d '30 days ago' +%s) ]]; then
    curl -X POST -H "Authorization: Bearer $TOKEN" \
      "$NETBIRD_API/api/peers/$peer_id/rotate-key"
    echo "Rotated key for peer $peer_id"
  fi
done
```

### Add to crontab:
```bash
# Run weekly key rotation check
0 0 * * 0 /opt/netbird/scripts/rotate-keys.sh >> /var/log/netbird-key-rotation.log 2>&1
```

## Complete Docker Compose Example

```yaml
version: "3.8"

services:
  dashboard:
    image: netbirdio/dashboard:latest
    environment:
      - NETBIRD_MGMT_API_ENDPOINT=https://api.your-domain.com
      - NETBIRD_MGMT_GRPC_API_ENDPOINT=api.your-domain.com:443
      - AUTH_AUDIENCE=netbird-client
      - AUTH_CLIENT_ID=netbird-dashboard
      - AUTH_AUTHORITY=https://your-oidc.com
      - USE_AUTH0=false
      - AUTH_SUPPORTED_SCOPES=openid profile email
      - AUTH_REDIRECT_URI=/auth
      - AUTH_SILENT_REDIRECT_URI=/silent-auth
      - NETBIRD_TOKEN_SOURCE=idToken
    
  management:
    image: netbirdio/management:latest
    volumes:
      - ./management.json:/etc/netbird/management.json
      - netbird-data:/var/lib/netbird
    environment:
      - NETBIRD_STORE_ENGINE=postgres
      - NETBIRD_DB_DSN=postgresql://netbird:password@postgres:5432/netbird
      - NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://your-oidc.com/.well-known/openid-configuration
      - NETBIRD_AUTH_AUDIENCE=netbird-client
      - NETBIRD_AUTH_CLIENT_ID=netbird-backend
      - NETBIRD_AUTH_CLIENT_SECRET=${OIDC_CLIENT_SECRET}
    command: |
      --port 443
      --log-level info
      --disable-anonymous-metrics
      --enable-api
      --enable-device-flow-auth
      --default-peer-expiration-enabled
      --default-peer-expiration-duration 720h
      --peer-login-expiration-enabled
      --peer-login-expiration-duration 24h

  signal:
    image: netbirdio/signal:latest
    environment:
      - NETBIRD_ENABLE_AUTH=true
      - NETBIRD_AUTH_ISSUER=https://your-oidc.com
      - NETBIRD_AUTH_AUDIENCE=netbird-signal

  postgres:
    image: postgres:14-alpine
    environment:
      - POSTGRES_DB=netbird
      - POSTGRES_USER=netbird
      - POSTGRES_PASSWORD=secure-password
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  netbird-data:
  postgres-data:
```

## Verification Commands

```bash
# Check ACL rules
curl -H "Authorization: Bearer $TOKEN" https://api.your-domain.com/api/rules

# Verify groups
curl -H "Authorization: Bearer $TOKEN" https://api.your-domain.com/api/groups

# Check DNS configuration
curl -H "Authorization: Bearer $TOKEN" https://api.your-domain.com/api/dns/settings

# Verify peer status and key age
curl -H "Authorization: Bearer $TOKEN" https://api.your-domain.com/api/peers
```

## Best Practices

1. **ACL Order Matters**: Place specific allow rules before the default-deny rule
2. **Use Groups**: Always use groups instead of individual peer IDs for scalability
3. **Regular Audits**: Review ACLs and access logs monthly
4. **Key Rotation**: Enforce automatic rotation with reasonable intervals (7-30 days)
5. **DNS Security**: Use DNS over TLS/HTTPS when possible
6. **Monitoring**: Enable logging and monitor failed connection attempts