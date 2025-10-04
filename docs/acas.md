# 🔐 NetBird + Keycloak Manual Setup & Hardening Guide

This tutorial walks you through configuring **self-hosted NetBird** with 
**Keycloak as IdP** and enforcing best-practice security (default-deny, 
least privilege, split tunneling, DNS, SSO/OIDC, and WireGuard key 
rotation).

---

## 📋 Prerequisites — What You Need

- ✅ **Self-hosted NetBird Management** up & running (you can reach the 
NetBird management URL).  
- ✅ **Admin access** to the NetBird Dashboard (or an API service account 
token).  
- ✅ **Keycloak** running and reachable by NetBird (**with TLS**) — 
Keycloak must be resolvable from inside the NetBird containers.  
  👉 [docs.netbird.io](https://docs.netbird.io)  
- ✅ **netbird CLI** installed on the client machines you’ll test from.  
  👉 [docs.netbird.io](https://docs.netbird.io)  
- ✅ `curl` and `jq` (optional) on your admin workstation for API calls.  

⚠️ Note: NetBird Cloud has extra provisioning features (IdP-Sync). 
Self-hosted differs slightly — this guide covers self-hosted setup.

---

## 🗂️ Quick Glossary

- **Peer** → a NetBird client / node (a machine on the mesh).  
- **Group** → logical collection of peers (e.g., devs, db-servers).  
- **Policy** → access control policy with rules (allow/deny).  
- **Exit node / Routing peer** → a peer that can be used as an egress 
(route Internet traffic).  
- **Setup Key** → pre-auth key used to enroll machines (useful for 
automation).  

---

## 1️⃣ Enforce SSO/OIDC Using Keycloak

### Goal
Make NetBird authenticate users via **Keycloak (OIDC)**. This is the 
foundation for group claims and SSO.

### A. Create a Keycloak Client for NetBird
1. Log into **Keycloak Admin Console**.  
2. Create a new Realm (or use existing).  
3. Go to **Clients → Create client**:  
   - Client ID: `netbird-frontend`  
   - Client protocol: `openid-connect`  
   - Root URL / Redirect URIs: your NetBird public URL (e.g., 
`https://netbird.example.com/*`)  
4. Enable **Standard Flow** (Authorization Code).  
5. Configure valid redirect URIs.  
6. Generate a **client secret** (you’ll paste it into NetBird later).  

👉 Optional: create a second “management” client if NetBird management 
needs to call Keycloak admin endpoints.  

📌 Tip: Keycloak must include **group/role claims** you want NetBird to 
use (see Section 2).

### B. Tell NetBird About Keycloak
1. Edit your NetBird **setup.env** and set OIDC variables:  

```bash
# Basic OIDC (example)
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT="https://keycloak.example.com/realms/yourrealm/.well-known/openid-configuration"
NETBIRD_AUTH_CLIENT_ID="netbird-frontend"
NETBIRD_AUTH_CLIENT_SECRET="<<CLIENT_SECRET_FROM_KEYCLOAK>>"
NETBIRD_AUTH_SUPPORTED_SCOPES="openid profile email groups"

# If you use a management client too:
NETBIRD_MGMT_IDP="keycloak"
NETBIRD_IDP_MGMT_CLIENT_ID="netbird-backend"
NETBIRD_IDP_MGMT_CLIENT_SECRET="<<MGMT_CLIENT_SECRET>>"
```

2. Save and restart NetBird management service / Docker containers.

3. Open NetBird Dashboard → it should redirect to Keycloak login.

---

## ✅ Verify SSO Login
- Open **NetBird Dashboard** in browser.  
- You should be **redirected to Keycloak login**.  

---

## 2 — Sync Keycloak Groups to NetBird (for policies)

### 🎯 Goal
Have Keycloak put a `groups` claim into JWT tokens and configure NetBird 
to extract groups from that claim (**JWT group sync**).

---

### A — Add Group Membership Mapper in Keycloak
1. Go to **Keycloak Admin → Clients → select NetBird client → Client 
Scopes or Mappers**.  
2. Add Mapper Type: **Group Membership**.  
3. Set **Token Claim Name** → `groups` (or any preferred claim name).  
4. Ensure it’s included in **ID or Access Token**.  
5. Save.  
👉 Keycloak docs: group mappers can inject a `groups` array into tokens.  

---

### B — Enable JWT Group Sync in NetBird
1. NetBird Dashboard → **Settings → Groups** (or API).  
2. Enable **JWT group sync** toggle.  
3. Set JWT claim to the same claim name as in Keycloak (e.g., `groups`).  
4. Optional: enable **auto-create groups**.  

---

### 🔍 Verify
- Log in as a user who is a member of a Keycloak group.  
- NetBird Dashboard should show that user in the mapped group(s).  
- If not: check audit logs and confirm token contains `groups` claim.  

⚠️ Caveat: Some **IdP-Sync automation features** exist only in NetBird 
Cloud.  
For **self-hosted**, use **JWT group sync + claim mapping**.  

---

## 3 — Implement Default-Deny Baseline

### 💡 Concept for Newbies
Default-deny means:  
- **Start by blocking everything**.  
- Then add **small, explicit allow rules**.  
- Prevents accidental exposure.  

---

### 🖥️ Step-by-Step (UI)
1. NetBird Dashboard → **Access Control → Groups** → create groups 
(`devs`, `web-servers`).  
2. Access Control → **Policies → Create Policy**.  
   - Allow source `devs` → destination `web-servers` → TCP 22,443.  
3. Save and test connectivity.  
4. **Delete or disable Default policy**.  
5. Test that flows not allowed are blocked.  

---

### 📡 Step-by-Step (API)
Get service token → create groups → create policy → delete default.  

```bash
API="https://netbird.example.com/api"
TOKEN="nbp_xxx"

# Create groups
curl -s -X POST "$API/groups" \
  -H "Authorization: Token $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name":"devs"}' | jq

curl -s -X POST "$API/groups" \
  -H "Authorization: Token $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name":"web-servers"}' | jq
# Insert the group IDs returned above into the policy JSON below
curl -s -X POST "$API/policies" \
  -H "Authorization: Token $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name":"allow-devs-to-web",
    "description":"Only SSH/HTTP/HTTPS from devs to web servers",
    "enabled": true,
    "rules":[
      {
        "name":"allow-ssh-http-https",
        "enabled": true,
        "action":"accept",
        "bidirectional": false,
        "protocol":"tcp",
        "ports":["22","80","443"],
        "sources":["<DEVS_GROUP_ID>"],
        "destinations":["<WEB_SERVERS_GROUP_ID>"]
      }
    ]
  }' | jq
```
