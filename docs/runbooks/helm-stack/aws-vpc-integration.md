# 📕 AI01 | AWS VPC Integration via NetBird Gateway

**Action Type**: Configuration | **Risk**: Medium | **Ops Book**: [../operations-book/README.md](../operations-book/README.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **AWS Access**: Permission to modify EC2 attributes and VPC Route Tables is confirmed.
- [ ] **Gateway Instance**: An EC2 instance in the target VPC is provisioned and reachable.
- [ ] **NetBird Management**: The management server is online and accessible from the VPC.

**STOP IF**: You do not have permission to disable Source/Destination checks on EC2 instances.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - AWS Infrastructure Preparation

1. **Disable Source/Destination Check**: In the EC2 Console, select the Gateway instance. Go to **Actions > Networking > Change source/destination check** and set it to **Stop**.
2. **Security Groups**: Update the security groups of your private VPC resources to allow inbound traffic from the **Private IP** of the NetBird Gateway instance.
3. **VPC Routing**: If not using masquerading, ensure the subnet routing table has a return route for the NetBird network (e.g., `100.64.0.0/10`) targeting the Gateway instance ID.

### STEP 02 - Deploy NetBird Gateway

```bash
# Install NetBird on the EC2 instance
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Connect to the management server
netbird up --management-url https://netbird.example.com
```

### STEP 03 - Configure Network Route (Dashboard)

1. Navigate to the NetBird Dashboard -> **Network Routes** -> **Add Route**.
2. **Network Range**: Enter your VPC CIDR (e.g., `172.31.0.0/16`).
3. **Routing Peer**: Select the EC2 Gateway instance.
4. **Masquerade**: Enable this to simplify routing without manual VPC route table updates.

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Gateway Status Verification

```bash
# Check the status on the EC2 gateway
netbird status
```

### V02 - Connectivity Test
From a remote NetBird-connected peer, attempt to `ping` a private IP address within the AWS VPC.

### V03 - Route Audit
Verify that the new route appears in the **Network Routes** section of the NetBird Dashboard with a "Connected" status.

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### R01 - Route Deletion
In the NetBird Dashboard, navigate to **Network Routes** and delete the VPC CIDR route.

### R02 - Gateway Deactivation
```bash
# Disconnect the NetBird client on the EC2 instance
netbird down
```

### R03 - AWS Reversion
Re-enable the Source/Destination check on the EC2 instance and remove any temporary security group rules.

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
