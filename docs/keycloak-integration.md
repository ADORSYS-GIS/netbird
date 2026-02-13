# Keycloak Integration Guide

How NetBird integrates with Keycloak for OIDC authentication. This deployment automates the configuration described in the [official NetBird Keycloak guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak).

---

## Architecture

```
                    ┌────────────────┐
                    │    Keycloak    │
                    │  (existing)    │
                    └────┬───────┬───┘
                         │       │
              ┌──────────┘       └──────────┐
              ▼                              ▼
   ┌─────────────────┐          ┌─────────────────┐
   │ netbird-backend │          │netbird-dashboard│
   │  (confidential) │          │    (public)      │
   │  service account│          │  PKCE + Device   │
   └────────┬────────┘          └────────┬────────┘
            │                            │
            ▼                            ▼
   ┌─────────────────┐          ┌─────────────────┐
   │   Management    │          │    Dashboard     │
   │   (backend)     │          │   (frontend)     │
   └─────────────────┘          └─────────────────┘
```

## What Terraform Creates

| Resource | Purpose |
|----------|---------|
| `keycloak_realm.netbird` | NetBird realm with security policies |
| `keycloak_openid_client.netbird_backend` | Confidential client for management API |
| `keycloak_openid_client.netbird_dashboard` | Public client for dashboard/CLI |
| `keycloak_openid_client_scope.groups` | Client scope for JWT group claims |
| `keycloak_openid_group_membership_protocol_mapper` | Maps groups into tokens |
| `keycloak_openid_audience_protocol_mapper` | Adds backend audience to dashboard tokens |
| `keycloak_group.netbird_admins` | Admin group |
| `keycloak_user.netbird_admin` | Default admin user |
| Service account roles | `view-users`, `query-users`, `query-groups`, `view-realm` |

## Dual-Client Architecture

NetBird uses **two Keycloak clients**:

### Backend Client (`netbird-backend`)
- **Type**: Confidential
- **Purpose**: Management API authentication, IdP user management
- **Features**: Service account enabled, client credentials grant
- **Scopes**: `openid`, `profile`, `email`, `offline_access`, `api`, `groups`

### Dashboard Client (`netbird-dashboard`)
- **Type**: Public
- **Purpose**: Dashboard login, CLI device authorization
- **Features**: PKCE (S256), device authorization grant
- **Scopes**: Same as backend + audience mapper pointing to backend client

## JWT Groups Claim

NetBird uses the `groups` claim in JWT tokens to sync user group memberships. This is set up automatically:

1. **Client Scope** (`groups`) — created with `include_in_token_scope = true`
2. **Group Membership Mapper** — adds `groups` claim with flat group names (not full path)
3. **Scope Assignment** — `groups` scope assigned as default to both clients

### Verifying Groups in Tokens

```bash
# Get a token (replace values)
TOKEN=$(curl -s -X POST \
  "https://<keycloak>/realms/netbird/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=netbird-dashboard" \
  -d "username=netbird-admin" \
  -d "password=<password>" \
  -d "scope=openid groups" | jq -r '.access_token')

# Decode and check groups claim
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq '.groups'
# Expected: ["netbird-admins"]
```

## Device Authorization Flow

Enabled on both clients for CLI login (`netbird up`):
1. Client requests device code from Keycloak
2. User visits the verification URL and enters the code
3. Client polls for token completion
4. Once approved, client receives access + refresh tokens

## Security Policies

The realm is configured with production-grade security:

| Policy | Setting |
|--------|---------|
| Password length | 12 characters minimum |
| Complexity | Upper + lower + digit + special char |
| Password expiry | 365 days |
| Brute-force | 5 attempts, then lockout escalation |
| Session idle | 30 minutes |
| Session max | 10 hours |
| Access token | 5 minutes |

## Adding Users

### Via Keycloak Admin
1. Go to Keycloak Admin → Users → Add User
2. Set email, enable account, verify email
3. Set Credentials → password
4. Go to Groups → assign to a group

### Via Terraform
Add to `keycloak.tf`:
```hcl
resource "keycloak_user" "new_user" {
  realm_id       = keycloak_realm.netbird.id
  username       = "john"
  email          = "john@example.com"
  email_verified = true
  enabled        = true
  initial_password {
    value     = "TempPassword123!"
    temporary = true
  }
}
```
