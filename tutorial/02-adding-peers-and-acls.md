# Adding Peers and Configuring ACLs

After deploying NetBird ([Tutorial 1](01-quick-start.md)), connect devices and set up access control.

---

## Step 1: Install NetBird Client

Install the NetBird client on a device you want to connect:

**Linux:**
```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
```

**macOS:**
```bash
brew install netbirdio/tap/netbird
```

**Windows:**  
Download from [netbird.io/download](https://netbird.io/download)

---

## Step 2: Connect Peer to Management Server

```bash
netbird up --management-url https://netbird.example.com
```

This will:
1. Open a browser for Keycloak authentication
2. Register the device with your NetBird management server
3. Establish a WireGuard tunnel

**Expected output:**
```
Connected
```

Check status:
```bash
netbird status
```

---

## Step 3: Verify Peer in Dashboard

1. Open `https://netbird.example.com`
2. Go to **Peers** → your device should appear
3. Note the assigned NetBird IP (e.g., `100.64.0.1`)

---

## Step 4: Create Peer Groups

Groups organize peers for access control:

1. Go to **Peers** → select a peer → **Groups** → Add to group
2. Or go to **Settings** → **Groups** → Create group

**Example groups:**
| Group | Purpose |
|-------|---------|
| `servers` | Production servers |
| `developers` | Developer workstations |
| `monitoring` | Monitoring systems |

---

## Step 5: Configure ACL Rules

Access Control Lists determine which groups can communicate:

1. Go to **Access Control** in the dashboard
2. Click **Add Rule**
3. Configure:
   - **Name**: `Developers to Servers`
   - **Source**: `developers`
   - **Destination**: `servers`
   - **Protocol**: All (or restrict to specific ports)
   - **Action**: Allow

**Example rules:**

| Rule | Source | Destination | Ports | Action |
|------|--------|-------------|-------|--------|
| Dev SSH | developers | servers | TCP 22 | Allow |
| Monitoring | monitoring | servers | TCP 9090, 9100 | Allow |
| Inter-dev | developers | developers | All | Allow |

> **Note**: NetBird uses an implicit deny model — traffic not explicitly allowed is blocked.

---

## Step 6: Test Connectivity

From a developer machine:
```bash
# Ping a server peer
ping 100.64.0.2

# SSH to a server (if ACL allows TCP 22)
ssh user@100.64.0.2
```

---

## Step 7: Configure Split Tunneling and DNS

### Split Tunneling
By default, only NetBird network traffic goes through the tunnel. To route specific networks:

1. Go to **Network Routes** in the dashboard
2. Click **Add Route**
3. Configure:
   - **Network**: `10.0.0.0/8` (your internal network)
   - **Peer**: Select a peer that can reach this network
   - **Groups**: Which groups get this route

### DNS
1. Go to **DNS** in the dashboard
2. Add a **Nameserver Group**:
   - **Nameserver**: `10.0.0.2:53`
   - **Domain**: `internal.example.com`
   - **Groups**: Which groups use this DNS

---

## Next Steps

- [Tutorial 3: Keycloak User Management](03-keycloak-user-management.md)
- [Keycloak Integration Details](../docs/keycloak-integration.md)
- [Troubleshooting](../docs/troubleshooting.md)
