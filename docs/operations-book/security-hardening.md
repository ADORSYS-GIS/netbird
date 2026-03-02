# Security Hardening

Security measures and best practices for the NetBird production infrastructure.

[[_TOC_]]

## Overview

<details open>
<summary>Expand/Collapse</summary>

```
┌──────────────────────────────────────────────────────────────┐
│                  SECURITY HARDENING WORKFLOW                 │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ S01 - NETWORK   │
    │ VPC & Firewall  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ S02 - ACCESS    │
    │ RBAC & SSH      │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ S03 - SECRETS   │
    │ Vault & Encr    │
    └─────────────────┘
```

### Defense in Depth Layers

| Layer | Implementation | Purpose |
|-------|----------------|---------|
| **VPC** | Cloud Security Groups | Public/Private isolation |
| **Host** | UFW Firewall | Application-specific access |
| **Edge** | HAProxy SSL/TLS | Secure termination |

</details>

---

## Procedures

<details open>
<summary>Expand/Collapse</summary>

### S01 - Network Segmentation

<details>
<summary>Execution Details</summary>

**1. Configure Security Groups:**
Restrict inbound traffic to Management Group (8081-8083, 9000) only from the Reverse Proxy CIDR.

**2. Verify Host Firewall (UFW):**
```bash
ansible all -i inventory/terraform_inventory.yaml -m shell -a "ufw status verbose"
```

</details>

### S02 - SSH & Access Hardening

<details>
<summary>Execution Details</summary>

**1. Disable Password Auth:**
Ensure `PasswordAuthentication no` is set in `/etc/ssh/sshd_config` across all nodes via the `common` Ansible role.

**2. Key Management:**
Only use Ed25519 or RSA 4096-bit keys for SSH access.

</details>

### S03 - Secrets & Encryption

<details>
<summary>Verification Details</summary>

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| DB Encryption | `sslmode=verify-full` | Enforced |
| State Secrets | `random_password` keepers | Active |
| Vault | `ansible-vault` | Recommended |

</details>

</details>

---

## Related Documentation

<details>
<summary>Expand/Collapse</summary>

| Document | Description |
|----------|-------------|
| [Architecture](../architecture.md) | Security model |
| [Monitoring](./monitoring-alerting.md) | Security alerts |

</details>
