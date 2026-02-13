# Keycloak User Management

Manage users, groups, and access for your NetBird deployment through Keycloak.

---

## Step 1: Access Keycloak Admin Console

1. Open `https://keycloak.example.com/admin`
2. Log in with your Keycloak admin credentials
3. Select the **netbird** realm from the dropdown (top-left)

---

## Step 2: Create New Users

1. Go to **Users** → **Add User**
2. Fill in:
   - **Username**: `john.doe`
   - **Email**: `john@example.com`
   - **Email Verified**: ON
   - **Enabled**: ON
3. Click **Save**
4. Go to **Credentials** tab → **Set Password**
   - Enter password (must meet policy: 12 chars, upper+lower+digit+special)
   - **Temporary**: ON (user must change on first login)

---

## Step 3: Assign Users to Groups

1. Go to **Users** → select the user
2. Click **Groups** tab → **Join Group**
3. Select a group (e.g., `netbird-admins`)
4. Click **Join**

**Available groups** (created by Terraform):
| Group | Purpose |
|-------|---------|
| `netbird-admins` | Full management access |

You can create additional groups for more granular control in Keycloak or NetBird.

---

## Step 4: Verify Group Claims in JWT Tokens

Test that the `groups` claim appears in tokens:

```bash
# Get a token for the user
TOKEN=$(curl -s -X POST \
  "https://keycloak.example.com/realms/netbird/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=netbird-dashboard" \
  -d "username=john.doe" \
  -d "password=<password>" \
  -d "scope=openid groups" | jq -r '.access_token')

# Decode the token payload
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq '.groups'
```

**Expected output:**
```json
["netbird-admins"]
```

If `groups` is missing, check [Troubleshooting → Groups not appearing in tokens](../docs/troubleshooting.md#groups-not-appearing-in-tokens).

---

## Step 5: Confirm User/Group Sync in NetBird

1. Have the user log in to the NetBird dashboard (`https://netbird.example.com`)
2. As admin, go to **Users** in the NetBird dashboard
3. The new user should appear with their Keycloak groups mapped

> **Note**: Users only appear in NetBird after their first login. Group sync happens on token refresh.

---

## Step 6: Revoking Access

### Temporarily disable a user
1. Keycloak Admin → **Users** → select user
2. Set **Enabled**: OFF
3. Click **Save**
4. Existing sessions will be terminated at next token refresh

### Remove from group
1. Keycloak Admin → **Users** → select user → **Groups**
2. Click **Leave** next to the group
3. User loses group-based access after token refresh

### Permanently delete a user
1. Keycloak Admin → **Users** → select user
2. Click **Delete** → Confirm
3. The user will be removed from NetBird on next sync

### Force immediate session termination
1. Keycloak Admin → **Users** → select user → **Sessions**
2. Click **Sign Out** to terminate all active sessions

---

## Bulk User Management via Terraform

For managing users as code, add to `keycloak.tf`:

```hcl
variable "netbird_users" {
  default = {
    "john" = { email = "john@example.com", groups = ["netbird-admins"] }
    "jane" = { email = "jane@example.com", groups = [] }
  }
}

resource "keycloak_user" "users" {
  for_each       = var.netbird_users
  realm_id       = keycloak_realm.netbird.id
  username       = each.key
  email          = each.value.email
  email_verified = true
  enabled        = true
  initial_password {
    value     = "TempP@ssw0rd!!"
    temporary = true
  }
}
```

---

## Next Steps

- [Keycloak Integration Details](../docs/keycloak-integration.md)
- [Troubleshooting](../docs/troubleshooting.md)
- [Upgrade Guide](../docs/upgrade-guide.md)
