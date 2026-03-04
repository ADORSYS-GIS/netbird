# NetBird Peer & Access Management

**Action Type**: Administration | **Risk**: Low | **Ops Book**: [Operations Book](../../operations-book/helm-stack/README.md)

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Client Software**: NetBird client is installed on the target device.
- [ ] **Management URL**: The correct management URL (e.g., `https://netbird.example.com`) is known.
- [ ] **Network Access**: The device has outbound access to TCP 443 and UDP 3478.

**STOP IF**: The management server is unreachable or if you do not have permission to add new peers.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Peer Connection

```bash
# Register the device with the management server
netbird up --management-url https://netbird.example.com
```

**Authentication**: A browser window will open for Keycloak login. Once authenticated, the device will establish a secure WireGuard tunnel.

### STEP 02 - Group Organization

1. Navigate to the NetBird Dashboard -> **Peers**.
2. Select the newly connected peer.
3. Assign it to the appropriate functional groups (e.g., `servers`, `developers`, `monitoring`).

### STEP 03 - Access Control (ACL) Configuration

1. Go to **Access Control** -> **Add Rule**.
2. Define the **Source Group**, **Destination Group**, and allowed **Protocols/Ports**.
3. **Note**: NetBird follows a Zero-Trust "Implicit Deny" model. Only traffic explicitly allowed by a rule can pass.

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Connectivity Status

```bash
# Check the connection status on the peer
netbird status

# Expected Output:
# Management: Connected
# Signal: Connected
```

### V02 - Access Rule Validation
Test connectivity between peers in the allowed groups (e.g., `ping` or `ssh` to the NetBird IP address `100.64.x.x`).

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### Peer Disconnection
```bash
# Disconnect and remove the local configuration
netbird down
```

### R02 - Peer Removal (Dashboard)
1. In the Dashboard, go to **Peers**.
2. Select the peer and click **Delete**.
3. This will immediately revoke the peer's access and cryptographic keys.

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
