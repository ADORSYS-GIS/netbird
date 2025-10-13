# Using Configuration Files and Scripting with NetBird

Below is a hands-on complement to the higher-level tutorial. Whenever the NetBird dashboard does not yet expose a setting, you can fall back to JSON configuration files or the public API. Adapt paths, versions, and API endpoints to your specific environment.

## Prerequisites

- **Self-hosted NetBird deployment**: Management, UI, and signal services available (Docker Compose or Kubernetes).
- **Access to generated artifacts**: Files such as `management.json`, `setup.env`, and any JSON produced by `configure.sh`.
- **Administrative credentials**: API tokens or CLI access to apply changes and redeploy services.

## Where Configuration Lives

- **Templates**: `docker-compose.yml.tmpl`, `management.json.tmpl`, and `setup.env` act as sources. The `configure.sh` script interpolates variables and writes final artifacts (for example `artifacts/management.json`).
- **Primary configuration**: `management.json` governs OIDC settings, policies, routing, DNS, and more.
- **API & CLI**: Certain tuning (for example key rotation) may require direct calls to the NetBird API.

---

## 1. Default-Deny and Granular ACLs in `management.json`

### 1.1 Policy Structure

```json
{
  "policies": [
    {
      "name": "devs-to-dbs",
      "description": "Allow devs to reach db servers on port 5432",
      "sourceGroups": ["devs"],
      "destinationGroups": ["db"],
      "protocol": "TCP",
      "ports": ["5432"]
    },
    {
      "name": "admin-to-all",
      "description": "Admins full access",
      "sourceGroups": ["admins"],
      "destinationGroups": ["*"],
      "protocol": "ANY",
      "ports": ["*"]
    }
  ],
  "peerGroups": [
    {
      "name": "devs",
      "peers": ["peer-id-1", "peer-id-2"]
    },
    {
      "name": "db",
      "peers": ["db-peer1"]
    },
    {
      "name": "admins",
      "peers": ["admin-peer"]
    }
  ]
}
```

1. Confirm no wildcard allow-all policies exist unless explicitly required—NetBird denies traffic that lacks an allow rule.
2. Map groups carefully so that source groups align with your identity provider (IdP) assignments.
3. Reapply or restart the management service after editing the file.

### 1.2 Port Ranges and Directional Rules

```json
{
  "name": "frontend-to-backend-range",
  "description": "Allow frontend → backend on 8000–8100",
  "sourceGroups": ["frontend"],
  "destinationGroups": ["backend"],
  "protocol": "TCP",
  "ports": ["8000-8100"],
  "direction": "OUTGOING"
}
```

- **Direction support**: Only include the `direction` field if your schema version supports it (check release notes). Otherwise omit it and rely on the conventional source-to-destination semantics.
- **Testing**: After deployment, validate flows from a representative peer in the `frontend` group.

### 1.3 Route-Level Access Control

```json
{
  "networks": [
    {
      "name": "corp-net",
      "description": "Corporate private network behind router-peer",
      "prefixes": ["10.20.0.0/16"],
      "routes": [
        {
          "routerPeerId": "peer-id-router",
          "enabled": true,
          "masquerade": true,
          "accessControlGroups": ["devs", "ops"]
        }
      ]
    }
  ]
}
```

- **Intent**: Restrict which groups can consume a network route even after it is advertised.
- **Enforcement**: With `accessControlGroups` in place, unmatched combinations silently drop traffic.
- **Lifecycle**: Restart management services so updated route permissions take effect.

---

## 2. Split Tunneling and Per-Group DNS via Configuration

### 2.1 Allowed Routes per Peer Group

```json
{
  "peerGroups": [
    {
      "name": "devs",
      "peers": ["peer1", "peer2"],
      "allowedRoutes": ["10.10.0.0/16", "10.20.30.0/24"]
    },
    {
      "name": "ops",
      "peers": ["peer3"],
      "allowedRoutes": ["10.10.0.0/16"]
    }
  ]
}
```

1. Enumerate only the subnets that must traverse the mesh—omit `0.0.0.0/0` to preserve local internet breakout.
2. For complex topologies, segment peer groups (for example `devs`, `ops`, `support`) and assign different route lists.
3. Redeploy management containers or pods to propagate the new routing tables.

### 2.2 DNS Servers and Policies per Group

```json
{
  "nameserverGroups": [
    {
      "name": "dev-dns",
      "servers": ["10.10.0.2"],
      "domains": ["internal.mycorp.local"]
    },
    {
      "name": "ops-dns",
      "servers": ["10.20.0.2", "10.20.0.3"],
      "domains": ["ops.internal.local"]
    }
  ],
  "peerGroups": [
    {
      "name": "devs",
      "peers": ["peer1", "peer2"],
      "dnsGroup": "dev-dns"
    },
    {
      "name": "ops",
      "peers": ["peer3"],
      "dnsGroup": "ops-dns"
    }
  ]
}
```

- **Nameserver groups** define resolver IPs and the domains they authoritatively handle.
- **Peer groups** reference a `dnsGroup`, ensuring internal names resolve against private DNS while other queries fall back to public resolvers.
- **Version check**: Verify your NetBird build supports nameserver groups; otherwise, look for CLI/API fallbacks.

---

## 3. Enforcing SSO / OIDC Settings

### 3.1 OIDC Block in `management.json`

```json
{
  "auth": {
    "type": "oidc",
    "oidc": {
      "issuer": "https://keycloak.example.com/realms/netbird",
      "clientId": "netbird-client",
      "clientSecret": "SECRET",
      "scopes": [
        "openid",
        "profile",
        "email",
        "offline_access",
        "api"
      ],
      "audience": "netbird-client",
      "groupClaim": "groups"
    }
  }
}
```

1. Align `issuer`, `clientId`, `clientSecret`, and `audience` with your IdP (for example Keycloak).
2. Configure JWT mappers so the `groupClaim` (commonly `groups`) reflects NetBird peer group names.
3. After modification, redeploy management to refresh SSO enforcement.

> **Tip:** Keep sensitive values (such as client secrets) in environment variables or external secrets management systems and inject them during templating.

---

## 4. WireGuard Key Rotation via Scripting

### 4.1 Rotation Workflow

1. **Fetch current peer configuration** using the NetBird API to capture the existing public key for audit purposes.
2. **Generate a new WireGuard key pair** on a secure host.
3. **Push the new public key** to the management API via `PUT /api/peers/{peerId}`.
4. **Verify connectivity** once the management service distributes updated configs.
5. **Retire the old key** after a safe overlap window (if dual-key support exists) or immediately if not.
6. **Log the rotation event** with timestamps, peer IDs, and key fingerprints.

### 4.2 Example Bash Script

```bash
#!/bin/bash
API="https://netbird.mycompany/api"
TOKEN="your_admin_api_token"
PEER_ID="peer-id-of-client"

# 1. Capture current peer details
curl -s -H "Authorization: Bearer $TOKEN" "$API/peers/$PEER_ID" > peer.json

# 2. Generate a new key pair
NEW_PRIV=$(wg genkey)
NEW_PUB=$(echo "$NEW_PRIV" | wg pubkey)

# 3. Update the peer's public key
curl -X PUT "$API/peers/$PEER_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"publicKey\": \"$NEW_PUB\"}"

# 4. Optional: wait and validate connectivity
sleep 30
# Implement checks such as ping or API health probes here

# 5. Optional cleanup (depends on API support)

# 6. Log the rotation
echo "$(date) rotated key for $PEER_ID, new pub: $NEW_PUB" >> keyrotations.log
```

- **Automation**: Integrate the script into cron, CI/CD workflows, or infrastructure-as-code pipelines.
- **Safety net**: Maintain a rollback plan (for example restore the prior public key) if peers fail to reconnect.

---

## Summary and Caveats

- **Use configuration files** when the UI lacks the required feature set (for example fine-grained ACLs, DNS policy nuances, or SSO claim mapping).
- **Redeploy management services** after file changes so the control plane reloads the new configuration.
- **Version awareness**: Not all schema attributes exist in every NetBird release—cross-check documentation before relying on new fields.
- **Test in staging first** to avoid unexpected downtime in production environments.
- **Automate key rotations** and track them with logs or observability tooling.