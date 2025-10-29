# Keycloak Deployment Architecture

Visual guide to understand NetBird Keycloak deployment modes and architecture.

---

## 🏗️ Architecture Overview

### Deploy Mode Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Host Machine                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │           Docker Compose Stack                     │  │
│  │                                                    │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Caddy Reverse Proxy                        │  │  │
│  │  │  - Automatic HTTPS (Let's Encrypt/nip.io)   │  │  │
│  │  │  - Ports: 80, 443, 443/udp                  │  │  │
│  │  └──────────────┬──────────────────────────────┘  │  │
│  │                 │                                  │  │
│  │                 ▼                                  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Keycloak 22.0                              │  │  │
│  │  │  - Port: 8080 (internal)                    │  │  │
│  │  │  - Realm: netbird                           │  │  │
│  │  │  - Clients: netbird-client, netbird-backend │  │  │
│  │  └──────────────┬──────────────────────────────┘  │  │
│  │                 │                                  │  │
│  │                 ▼                                  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  PostgreSQL 15                              │  │  │
│  │  │  - Port: 5432 (internal)                    │  │  │
│  │  │  - Database: keycloak                       │  │  │
│  │  │  - Persistent volume                        │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        │ HTTPS/HTTP
                        ▼
                 ┌─────────────┐
                 │   Users     │
                 │  NetBird    │
                 └─────────────┘
```

**Key Features:**
- ✅ Self-contained Keycloak deployment
- ✅ Automatic SSL certificate management
- ✅ PostgreSQL for data persistence
- ✅ Reverse proxy with Caddy
- ✅ Complete identity provider solution

---

### External Mode Architecture

```
┌──────────────────────────────────────────────────────────┐
│              External Keycloak Server                     │
│                (Managed by Admin/Boss)                    │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Keycloak Production Instance                      │  │
│  │  - URL: login.wazuh.adorsys.team                   │  │
│  │  - Realm: netbird (existing)                       │  │
│  │  - Clients: Created by Ansible                     │  │
│  │    • netbird-client (public)                       │  │
│  │    • netbird-backend (service account)             │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │
                       │ OIDC/OAuth2 (HTTPS)
                       │
                       ▼
        ┌──────────────────────────────────┐
        │   Ansible Control Node           │
        │   - Validates connectivity       │
        │   - Creates/updates OAuth clients│
        │   - Exports NetBird config       │
        └──────────────────────────────────┘
                       │
                       │ Configuration Output
                       ▼
        ┌──────────────────────────────────┐
        │   NetBird Deployment             │
        │   - Uses external Keycloak       │
        │   - No local identity provider   │
        │   - Centralized authentication   │
        └──────────────────────────────────┘
```

**Key Features:**
- ✅ Leverages existing enterprise Keycloak
- ✅ No infrastructure deployment needed
- ✅ Centralized identity management
- ✅ Integration with existing user directory
- ✅ Service account authentication

---

## 🔄 OAuth Flow Comparison

### Deploy Mode OAuth Flow

```
┌──────────┐                ┌──────────────┐               ┌──────────────┐
│  NetBird │                │   Caddy      │               │  Keycloak    │
│Dashboard │                │ (Reverse     │               │  (Local)     │
│          │                │  Proxy)      │               │              │
└────┬─────┘                └──────┬───────┘               └──────┬───────┘
     │                              │                              │
     │ 1. Access Dashboard          │                              │
     ├─────────────────────────────>│                              │
     │                              │                              │
     │ 2. Redirect to Auth          │                              │
     │<─────────────────────────────┤                              │
     │                              │                              │
     │ 3. Authorization Request     │                              │
     ├──────────────────────────────┼─────────────────────────────>│
     │                              │                              │
     │ 4. Login Page                │                              │
     │<─────────────────────────────┼──────────────────────────────┤
     │                              │                              │
     │ 5. Credentials               │                              │
     ├──────────────────────────────┼─────────────────────────────>│
     │                              │                              │
     │ 6. Authorization Code        │                              │
     │<─────────────────────────────┼──────────────────────────────┤
     │                              │                              │
     │ 7. Exchange Code for Token   │                              │
     ├──────────────────────────────┼─────────────────────────────>│
     │                              │                              │
     │ 8. Access Token + ID Token   │                              │
     │<─────────────────────────────┼──────────────────────────────┤
     │                              │                              │
     │ 9. Access Dashboard          │                              │
     │<─────────────────────────────┤                              │
     │                              │                              │
```

### External Mode OAuth Flow

```
┌──────────┐          ┌──────────────┐          ┌────────────────────┐
│  NetBird │          │   NetBird    │          │  External Keycloak │
│Dashboard │          │  Management  │          │ (login.wazuh...)   │
│          │          │              │          │                    │
└────┬─────┘          └──────┬───────┘          └──────┬─────────────┘
     │                       │                         │
     │ 1. Access Dashboard   │                         │
     ├──────────────────────>│                         │
     │                       │                         │
     │ 2. Redirect to SSO    │                         │
     │<──────────────────────┤                         │
     │                       │                         │
     │ 3. SSO Authorization Request                    │
     ├─────────────────────────────────────────────────>│
     │                       │                         │
     │ 4. Authenticate (may use existing session)      │
     │<────────────────────────────────────────────────┤
     │                       │                         │
     │ 5. Authorization Code │                         │
     │<────────────────────────────────────────────────┤
     │                       │                         │
     │ 6. Exchange Code      │                         │
     ├─────────────────────────────────────────────────>│
     │                       │                         │
     │ 7. Access Token       │                         │
     │<────────────────────────────────────────────────┤
     │                       │                         │
     │ 8. Access Dashboard   │                         │
     │<──────────────────────┤                         │
     │                       │                         │
     │                       │ 9. Validate Token       │
     │                       ├────────────────────────>│
     │                       │                         │
     │                       │ 10. User Info           │
     │                       │<────────────────────────┤
     │                       │                         │
```

---

## 🔐 OAuth Client Configuration

### netbird-client (Public Client)

**Purpose:** Dashboard and CLI authentication

```
┌─────────────────────────────────────────────┐
│         netbird-client Configuration        │
├─────────────────────────────────────────────┤
│ Client ID:         netbird-client           │
│ Client Type:       Public                   │
│ Access Type:       Public                   │
│ Standard Flow:     ✅ Enabled                │
│ Direct Access:     ✅ Enabled                │
│ Service Account:   ❌ Disabled               │
│                                             │
│ Valid Redirect URIs:                        │
│  • https://netbird.company.com/*            │
│  • http://localhost:53000                   │
│                                             │
│ Web Origins:                                │
│  • https://netbird.company.com              │
│  • + (allow all)                            │
│                                             │
│ Protocol:          openid-connect           │
│ Access Token:      Short-lived             │
│ Refresh Token:     ✅ Enabled                │
└─────────────────────────────────────────────┘
```

### netbird-backend (Service Account)

**Purpose:** Management API server-to-server authentication

```
┌─────────────────────────────────────────────┐
│      netbird-backend Configuration          │
├─────────────────────────────────────────────┤
│ Client ID:         netbird-backend          │
│ Client Type:       Confidential             │
│ Access Type:       Confidential             │
│ Standard Flow:     ❌ Disabled               │
│ Service Account:   ✅ Enabled                │
│ Authorization:     ✅ Enabled                │
│ Device Flow:       ✅ Enabled                │
│                                             │
│ Client Secret:     <generated/provided>     │
│                                             │
│ Valid Redirect URIs:                        │
│  • https://netbird.company.com/*            │
│                                             │
│ Service Account Roles:                      │
│  • realm-management: manage-users           │
│  • realm-management: view-users             │
│                                             │
│ Protocol:          openid-connect           │
│ Access Token:      Long-lived              │
└─────────────────────────────────────────────┘
```

---

## 📊 Deployment Mode Comparison Matrix

| Feature | Deploy Mode | External Mode |
|---------|-------------|---------------|
| **Infrastructure** |
| Keycloak Server | ✅ Deploys new | ❌ Uses existing |
| PostgreSQL Database | ✅ Deploys new | ❌ Uses existing |
| Reverse Proxy | ✅ Caddy (ports 80/443) | ❌ Not needed |
| SSL Certificates | ✅ Automatic (Let's Encrypt/self-signed) | ℹ️ Existing server's |
| **Configuration** |
| Admin Access | ✅ Full admin account | ⚠️ Service account only |
| Realm Creation | ✅ Creates new realm | ❌ Uses existing realm |
| Client Creation | ✅ Creates OAuth clients | ✅ Creates OAuth clients |
| User Management | ✅ Full control | ⚠️ Limited (via service account) |
| **Networking** |
| Ports Required | 80, 443, 8080 | None (client only) |
| External Access | ✅ Public/private | ℹ️ Depends on existing |
| Docker Network | ✅ Internal bridge | ❌ Not applicable |
| **Maintenance** |
| Updates | 🔧 You manage | ✅ Admin manages |
| Backups | 🔧 You manage | ✅ Admin manages |
| Monitoring | 🔧 You manage | ✅ Admin manages |
| Scaling | 🔧 Manual | ✅ Centrally managed |
| **Security** |
| Certificate Management | 🔧 Automatic renewal | ✅ Admin manages |
| User Directory | 🔧 Local PostgreSQL | ✅ Centralized (LDAP/AD) |
| SSO Integration | ⚠️ Manual setup | ✅ Already integrated |
| MFA/2FA | ⚠️ Manual setup | ✅ Centrally enforced |
| **Use Cases** |
| Best For | Testing, demos, standalone | Production, enterprise |
| Complexity | 🟡 Moderate | 🟢 Low (setup) |
| Dependencies | 🟢 None | 🟡 Admin coordination |
| Time to Deploy | 🟡 10-15 minutes | 🟢 5 minutes |

---

## 🌐 Network Flow Diagrams

### Deploy Mode Network Flow

```
Internet
   │
   │ HTTPS (443)
   ▼
┌──────────────────────────┐
│  Caddy Reverse Proxy     │  ← Automatic SSL termination
│  (Docker Container)      │
└────────┬─────────────────┘
         │
         │ HTTP (8080) - Internal Docker Network
         ▼
┌──────────────────────────┐
│  Keycloak Server         │
│  (Docker Container)      │  ← OIDC/OAuth2 Provider
└────────┬─────────────────┘
         │
         │ PostgreSQL Protocol (5432) - Internal Docker Network
         ▼
┌──────────────────────────┐
│  PostgreSQL Database     │
│  (Docker Container)      │  ← Persistent Data
└──────────────────────────┘

Docker Volumes:
  • keycloak_postgres_data (Database)
  • keycloak_data (Keycloak files)
  • caddy_data (SSL certificates)
  • caddy_config (Caddy config)
```

### External Mode Network Flow

```
Internet
   │
   │ HTTPS (443)
   ▼
┌─────────────────────────────────┐
│  External Keycloak Server       │  ← Managed by Admin
│  login.wazuh.adorsys.team       │
└────────┬────────────────────────┘
         │
         │ OIDC Discovery
         │ Token Endpoints
         │ User Info Endpoints
         ▼
┌─────────────────────────────────┐
│  NetBird Management Server      │  ← Your deployment
│  (Validates tokens)             │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  NetBird Clients                │  ← End users
│  (Dashboard, CLI, Mobile)       │
└─────────────────────────────────┘
```

---

## 🔄 Data Flow

### User Authentication Flow (Deploy Mode)

```
1. User Access
   Browser → https://YOUR_HOST/dashboard
              ↓
2. SSL Termination
   Caddy (443) → Keycloak (8080)
              ↓
3. Authentication
   Keycloak → PostgreSQL (user lookup)
              ↓
4. Token Generation
   Keycloak → Signs JWT token
              ↓
5. Return to App
   Browser ← Redirect with auth code
              ↓
6. Token Exchange
   NetBird → Keycloak (exchange code for token)
              ↓
7. Access Granted
   User authenticated in NetBird Dashboard
```

### User Authentication Flow (External Mode)

```
1. User Access
   Browser → https://netbird.company.com
              ↓
2. SSO Redirect
   NetBird → https://login.wazuh.adorsys.team
              ↓
3. Existing Session Check
   Keycloak → Checks for existing SSO session
              ↓
4. Authentication (if needed)
   User → Authenticates with corporate credentials
              ↓
5. Token Generation
   Keycloak → Signs JWT with company keys
              ↓
6. Return to NetBird
   Browser ← Redirect with auth code
              ↓
7. Token Validation
   NetBird Management → Validates token with Keycloak
              ↓
8. Access Granted
   User authenticated with SSO
```

---

## 🛠️ Configuration File Structure

### Deploy Mode Configuration Files

```
/opt/keycloak/
├── docker-compose.yml          ← Generated by Ansible
│   ├── keycloak_db (PostgreSQL)
│   ├── keycloak (Keycloak 22.0)
│   └── caddy (Reverse Proxy)
│
├── Caddyfile                   ← Generated by Ansible
│   └── SSL + Reverse Proxy Config
│
└── Docker Volumes:
    ├── keycloak_postgres_data/ ← Database files
    ├── keycloak_data/          ← Keycloak files
    ├── caddy_data/             ← SSL certificates
    └── caddy_config/           ← Caddy config

deploy/
├── group_vars/
│   ├── keycloak.yml           ← Main configuration
│   └── vault.yml              ← Encrypted secrets
│
└── netbird-external-config.env ← Generated output
    └── NetBird integration variables
```

### External Mode Configuration Files

```
deploy/
├── group_vars/
│   ├── keycloak.yml           ← OIDC endpoint config
│   └── vault.yml              ← Client secrets
│
└── netbird-external-config.env ← Generated output
    └── NetBird integration variables

No infrastructure files created on target hosts!
```

---

## 📈 Decision Tree: Which Mode to Use?

```
Start: Need Keycloak for NetBird?
│
├─ Do you have an existing Keycloak server?
│  ├─ YES → Do you have admin access or service account?
│  │         ├─ YES → Use EXTERNAL MODE ✅
│  │         └─ NO  → Request access from admin, then EXTERNAL MODE
│  │
│  └─ NO → Do you need centralized identity management?
│           ├─ YES → Deploy new Keycloak → DEPLOY MODE ✅
│           └─ NO  → Testing/Development → DEPLOY MODE ✅
│
Decision Matrix:
│
├─ Production Enterprise Environment
│  └─ EXTERNAL MODE (centralized auth, existing infra)
│
├─ Production Standalone Environment
│  └─ DEPLOY MODE (self-contained, full control)
│
├─ Development/Testing
│  └─ DEPLOY MODE (quick setup, isolated)
│
└─ Multi-tenant/Multi-service Architecture
   └─ EXTERNAL MODE (shared identity provider)
```

---

## 🔍 Security Considerations

### Deploy Mode Security

```
┌─────────────────────────────────────────┐
│         Security Layer                  │
├─────────────────────────────────────────┤
│ 1. SSL/TLS (Caddy)                      │
│    • Automatic certificate renewal      │
│    • HTTPS enforcement                  │
│    • TLS 1.2+ only                      │
│                                         │
│ 2. Network Isolation                    │
│    • Internal Docker network            │
│    • PostgreSQL not exposed externally  │
│    • Keycloak behind reverse proxy      │
│                                         │
│ 3. Authentication                       │
│    • Strong admin passwords (vault)     │
│    • OAuth 2.0 / OIDC                   │
│    • JWT token validation               │
│                                         │
│ 4. Database Security                    │
│    • PostgreSQL password (vault)        │
│    • No external access                 │
│    • Persistent encrypted volumes       │
│                                         │
│ 5. Secrets Management                   │
│    • Ansible Vault encryption           │
│    • No plaintext passwords             │
│    • Secure client secrets              │
└─────────────────────────────────────────┘
```

### External Mode Security

```
┌─────────────────────────────────────────┐
│         Security Layer                  │
├─────────────────────────────────────────┤
│ 1. Enterprise SSL/TLS                   │
│    • Managed by admin                   │
│    • Corporate certificates             │
│    • Certificate validation enforced    │
│                                         │
│ 2. Centralized Authentication           │
│    • Corporate SSO                      │
│    • LDAP/AD integration                │
│    • Existing MFA/2FA policies          │
│                                         │
│ 3. Service Account                      │
│    • Limited permissions                │
│    • Client secret (vault)              │
│    • No user password exposure          │
│                                         │
│ 4. Token Validation                     │
│    • JWT signature verification         │
│    • Token expiration enforcement       │
│    • Audience claim validation          │
│                                         │
│ 5. Audit & Compliance                   │
│    • Centralized logging                │
│    • Corporate audit trails             │
│    • Compliance enforcement             │
└─────────────────────────────────────────┘
```

---

## 📚 Related Documentation

- **[KEYCLOAK_CONFIGURATION_GUIDE.md](./KEYCLOAK_CONFIGURATION_GUIDE.md)** - Complete setup guide
- **[KEYCLOAK_QUICK_REFERENCE.md](./KEYCLOAK_QUICK_REFERENCE.md)** - Quick reference card
- **[../README.md](../README.md)** - Main project documentation

---

This architecture guide provides a visual understanding of how NetBird integrates with Keycloak in both deployment modes. Choose the mode that best fits your infrastructure and security requirements.
