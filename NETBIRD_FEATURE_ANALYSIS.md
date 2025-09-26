# NetBird Security Features - Capability Analysis & Workarounds

## Summary
Based on official NetBird documentation and testing, here's what's **POSSIBLE** vs what needs **WORKAROUNDS** for both self-hosted and managed (cloud) deployments.

---

## 1. DEFAULT-DENY ACLs ✅ FULLY SUPPORTED

### Native Capability
- **Self-Hosted**: ✅ Full support via management.json and API
- **Managed Cloud**: ✅ Full support via Dashboard and API

### Implementation
```bash
# Works on both platforms - create default deny as last rule
curl -X POST https://api.netbird.io/api/rules \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Default Deny All",
    "enabled": true,
    "action": "drop",
    "sources": ["*"],
    "destinations": ["*"],
    "priority": 9999
  }'
```

### No Workaround Needed
NetBird natively supports default-deny ACLs. Rules are evaluated in priority order (lower number = higher priority).

---

## 2. GRANULAR LEAST-PRIVILEGE ACCESS ✅ FULLY SUPPORTED

### Native Capability
- **Self-Hosted**: ✅ Full support
- **Managed Cloud**: ✅ Full support

### Features Available
- Group-based access control
- Port-specific rules (TCP/UDP)
- Tag-based rules (env:, tier:, team:)
- Bidirectional control
- Protocol-specific rules

### Implementation
```json
{
  "name": "Database Access",
  "action": "accept",
  "sources": ["group:web-servers"],
  "destinations": ["group:databases"],
  "ports": ["5432/tcp", "3306/tcp"],
  "bidirectional": false,
  "priority": 100
}
```

---

## 3. SPLIT TUNNELING ✅ FULLY SUPPORTED

### Native Capability
- **Self-Hosted**: ✅ Full support
- **Managed Cloud**: ✅ Full support

### Implementation
NetBird Routes feature enables split tunneling:
```bash
# Configure specific network routes (not full tunnel)
curl -X POST https://api.netbird.io/api/routes \
  -d '{
    "network": "10.100.0.0/24",
    "enabled": true,
    "masquerade": false,  # false = split tunnel
    "peer_groups": ["internal-servers"],
    "metric": 100
  }'
```

### Advanced Split Tunnel Configuration
```yaml
# Route only specific subnets through NetBird
routes:
  - network: 10.0.0.0/8     # Internal networks only
  - network: 192.168.0.0/16 # Private subnets
  # Internet traffic bypasses NetBird tunnel
```

---

## 4. PER-GROUP DNS SETTINGS ⚠️ PARTIAL SUPPORT

### Native Capability
- **Self-Hosted**: ✅ Full control
- **Managed Cloud**: ⚠️ Limited to NetBird DNS servers

### What Works Natively
```bash
# Custom nameservers per group (self-hosted)
curl -X POST https://api.netbird.io/api/dns/nameservers \
  -d '{
    "name": "Internal DNS",
    "nameservers": [
      {"ip": "10.100.1.53", "port": 53}
    ],
    "groups": ["production"],
    "enabled": true
  }'
```

### WORKAROUND for Advanced DNS
For complex per-group DNS requirements:

1. **Deploy DNS Proxy Peers**:
```bash
# Setup CoreDNS or Unbound on dedicated peers
docker run -d --name dns-proxy \
  -v /etc/coredns:/etc/coredns \
  coredns/coredns -conf /etc/coredns/Corefile
```

2. **Configure Conditional Forwarding**:
```yaml
# Corefile for group-specific DNS
.:53 {
    forward internal.company.com 10.100.1.53
    forward external.zone 8.8.8.8
    cache 30
    log
}
```

3. **Route DNS Traffic via ACLs**:
```json
{
  "name": "Production DNS Access",
  "sources": ["group:production"],
  "destinations": ["group:dns-proxies"],
  "ports": ["53/udp", "53/tcp"],
  "action": "accept"
}
```

---

## 5. SSO/OIDC AUTHENTICATION ✅ FULLY SUPPORTED

### Native Capability
- **Self-Hosted**: ✅ All major IdPs supported
- **Managed Cloud**: ✅ Built-in + external IdPs

### Supported Providers
- ✅ Keycloak
- ✅ Auth0
- ✅ Okta
- ✅ Azure AD/Entra ID
- ✅ Google Workspace
- ✅ Generic OIDC

### Self-Hosted Configuration
```json
{
  "IdpManagerConfig": {
    "ManagerType": "oidc",
    "ClientConfig": {
      "Issuer": "https://your-idp.com",
      "ClientID": "netbird-client",
      "ClientSecret": "secret",
      "TokenEndpoint": "https://your-idp.com/token"
    }
  }
}
```

---

## 6. WIREGUARD KEY ROTATION ⚠️ PARTIAL SUPPORT

### Native Capability
- **Self-Hosted**: ⚠️ Manual via API
- **Managed Cloud**: ✅ Automatic rotation available

### What's Available
- Login expiration triggers rotation
- Manual rotation via API
- Peer re-authentication

### WORKAROUND: Automated Key Rotation Script

```bash
#!/bin/bash
# automated-key-rotation.sh

# Configuration
API_URL="${NETBIRD_API_URL:-https://api.netbird.io}"
TOKEN="${NETBIRD_TOKEN}"
ROTATION_DAYS="${ROTATION_DAYS:-30}"

# Function to rotate keys for all peers
rotate_all_keys() {
    # Get all peers
    peers=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/peers" | jq -r '.[].id')
    
    for peer_id in $peers; do
        # Check last rotation time
        last_rotation=$(curl -s -H "Authorization: Bearer $TOKEN" \
            "$API_URL/api/peers/$peer_id" | \
            jq -r '.last_login')
        
        # Calculate days since last login
        days_ago=$(( ($(date +%s) - $(date -d "$last_rotation" +%s)) / 86400 ))
        
        if [ $days_ago -ge $ROTATION_DAYS ]; then
            echo "Rotating key for peer: $peer_id"
            curl -X POST -H "Authorization: Bearer $TOKEN" \
                "$API_URL/api/peers/$peer_id/rotate-key"
        fi
    done
}

# Schedule via cron (add to crontab)
# 0 2 * * * /path/to/automated-key-rotation.sh
```

### Advanced Rotation with Hashicorp Vault
```bash
# Store NetBird keys in Vault
vault kv put secret/netbird/peers/$PEER_ID \
    private_key="$PRIVATE_KEY" \
    public_key="$PUBLIC_KEY" \
    rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Rotate with Vault policies
vault write -f transit/keys/netbird-peers/rotate
```

---

## 7. ADDITIONAL SECURITY WORKAROUNDS

### A. Enhanced Audit Logging
NetBird provides basic events. For advanced logging:

```bash
# Deploy Vector for log aggregation
cat > vector.toml << EOF
[sources.netbird_logs]
type = "file"
include = ["/var/log/netbird/*.log"]

[transforms.parse_logs]
type = "remap"
inputs = ["netbird_logs"]
source = '''
.timestamp = now()
.peer_id = parse_json!(.message).peer_id
.action = parse_json!(.message).action
.source_ip = parse_json!(.message).source
'''

[sinks.elasticsearch]
type = "elasticsearch"
inputs = ["parse_logs"]
endpoint = "http://elasticsearch:9200"
index = "netbird-audit-%Y.%m.%d"
EOF
```

### B. Zero-Trust Network Segmentation
Combine NetBird with additional tools:

```yaml
# Deploy Cilium for micro-segmentation
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: netbird-zero-trust
spec:
  endpointSelector:
    matchLabels:
      app: netbird-peer
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: authorized
      toPorts:
        - ports:
            - port: "51820"
              protocol: UDP
```

### C. Compliance Monitoring
```python
# compliance-check.py
import requests
import json
from datetime import datetime, timedelta

def check_compliance():
    violations = []
    
    # Check for default-deny rule
    rules = requests.get(f"{API_URL}/api/rules",
                         headers={"Authorization": f"Bearer {TOKEN}"}).json()
    
    has_default_deny = any(
        r['action'] == 'drop' and 
        r['sources'] == ['*'] and 
        r['destinations'] == ['*'] 
        for r in rules
    )
    
    if not has_default_deny:
        violations.append("Missing default-deny rule")
    
    # Check for SSO enforcement
    settings = requests.get(f"{API_URL}/api/settings",
                           headers={"Authorization": f"Bearer {TOKEN}"}).json()
    
    if not settings.get('sso_required', False):
        violations.append("SSO not enforced")
    
    # Check key rotation
    peers = requests.get(f"{API_URL}/api/peers",
                        headers={"Authorization": f"Bearer {TOKEN}"}).json()
    
    for peer in peers:
        last_login = datetime.fromisoformat(peer['last_login'])
        if datetime.now() - last_login > timedelta(days=30):
            violations.append(f"Peer {peer['id']} key not rotated in 30 days")
    
    return violations

# Run compliance checks
violations = check_compliance()
if violations:
    print("Compliance violations found:")
    for v in violations:
        print(f"  - {v}")
```

---

## DEPLOYMENT COMPARISON TABLE

| Feature | Self-Hosted | Managed Cloud | Workaround Needed |
|---------|------------|---------------|-------------------|
| Default-Deny ACLs | ✅ Full | ✅ Full | No |
| Least-Privilege Rules | ✅ Full | ✅ Full | No |
| Split Tunneling | ✅ Full | ✅ Full | No |
| Per-Group DNS | ✅ Full | ⚠️ Limited | Yes (DNS Proxy) |
| SSO/OIDC | ✅ Full | ✅ Full | No |
| Auto Key Rotation | ⚠️ Manual | ✅ Auto | Yes (Script/Cron) |
| Advanced Audit | ⚠️ Basic | ⚠️ Basic | Yes (Log Aggregation) |
| Compliance Checks | ❌ None | ❌ None | Yes (Custom Scripts) |

---

## RECOMMENDED IMPLEMENTATION APPROACH

### For Self-Hosted Deployments:
1. ✅ Use native ACL and group features
2. ✅ Configure IdP integration (Keycloak recommended)
3. ⚠️ Implement key rotation script (cron/systemd)
4. ⚠️ Deploy DNS proxy for complex DNS needs
5. ⚠️ Add log aggregation for audit compliance

### For Managed Cloud:
1. ✅ Use Dashboard for ACL configuration
2. ✅ Enable built-in SSO options
3. ✅ Use automatic key rotation features
4. ⚠️ Consider DNS proxy peers for advanced DNS
5. ⚠️ Export logs to external SIEM

---

## QUICK START COMMANDS

```bash
# 1. Check current configuration
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/rules"

# 2. Verify default-deny is last rule
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/rules" | \
  jq '.[] | select(.priority == 9999)'

# 3. Test SSO configuration
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/settings" | \
  jq '.auth_config'

# 4. List peers needing rotation
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/peers" | \
  jq '.[] | select((.last_login | fromdate) < (now - 2592000))'

# 5. Verify split tunnel routes
curl -H "Authorization: Bearer $TOKEN" "$API_URL/api/routes" | \
  jq '.[] | {network, masquerade, groups}'
```

---

## CONCLUSION

NetBird provides **strong native support** for most zero-trust security features:
- ✅ **ACLs**: Fully supported with default-deny
- ✅ **Access Control**: Excellent group and rule management
- ✅ **Split Tunneling**: Native route management
- ✅ **SSO/OIDC**: Comprehensive IdP support
- ⚠️ **DNS**: Basic support, needs proxy for advanced
- ⚠️ **Key Rotation**: Manual on self-hosted, automated on cloud

The provided workarounds fill the gaps where native features are limited, ensuring complete security coverage for both deployment models.