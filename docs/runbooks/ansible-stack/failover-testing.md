# High Availability Failover Runbook

Procedures for testing and verifying the high availability and failover mechanisms of the NetBird production cluster.

[[_TOC_]]

## Overview

<details open>
<summary>Expand/Collapse</summary>

```
┌──────────────────────────────────────────────────────────────┐
│                  HA FAILOVER TESTING WORKFLOW                │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ HA01 - NETWORK  │
    │ VIP Failover    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ HA02 - TRAFFIC  │
    │ LB / Proxy      │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ HA03 - APP      │
    │ Mgmt Node Down  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ HA04 - DATA     │
    │ PgBouncer / DB  │
    └─────────────────┘
```

A production-ready HA cluster must be regularly tested for failure scenarios. This runbook covers the four primary failure domains:

| Test ID | Domain | Component | Expected Recovery |
|---------|--------|-----------|-------------------|
| **HA01** | Networking | Keepalived VRRP | < 5 seconds |
| **HA02** | Traffic | HAProxy Service | Instant (via VIP) |
| **HA03** | Application | Management Node | < 5 seconds |
| **HA04** | Data | PgBouncer Pooler | < 10 seconds |

</details>

---

## Failover Procedures

<details open>
<summary>Expand/Collapse</summary>

### HA01 - Virtual IP Failover (Keepalived)

<details>
<summary>Failure Simulation</summary>

**1. Identify Active Node:**
SSH to a proxy node and check if it holds the VIP:
```bash
ansible reverse_proxy -i inventory/terraform_inventory.yaml -m shell -a "ip addr show | grep -E '10\.|vrrp'"
```

**2. Stop Service on Primary:**
```bash
ansible <primary-proxy-node> -i inventory/terraform_inventory.yaml -m shell -a "sudo systemctl stop keepalived"
```

**3. Monitor Backup Node:**
The VIP should appear on the backup node within 3 seconds. Verify:
```bash
ansible <backup-proxy-node> -i inventory/terraform_inventory.yaml -m shell -a "ip addr show | grep -E '10\.|vrrp'"
```

**4. Recovery:**
Restart Keepalived on the primary to test preemption:
```bash
ansible <primary-proxy-node> -i inventory/terraform_inventory.yaml -m shell -a "sudo systemctl start keepalived"
```

</details>

### HA02 - HAProxy Service Failure

<details>
<summary>Failure Simulation</summary>

**1. Stop HAProxy on Active Node:**
```bash
ansible <active-proxy-node> -i inventory/terraform_inventory.yaml -m shell -a "sudo systemctl stop haproxy"
```

**2. Verify Traffic Routing:**
Keepalived (if configured with `track_script`) should immediately drop the VIP, causing it to move to the healthy node.

**3. Recovery:**
```bash
ansible <active-proxy-node> -i inventory/terraform_inventory.yaml -m shell -a "sudo systemctl start haproxy"
```

</details>

### HA03 - Management Node Failover

<details>
<summary>Failure Simulation</summary>

**1. Stop Application on Node 1:**
```bash
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml -m shell -a "cd /opt/netbird && docker-compose stop netbird-management"
```

**2. Verify Cluster Health:**
Check HAProxy stats (`https://<domain>:8404/stats`). The backend for the stopped node should turn red (DOWN).

**3. Test Connectivity:**
NetBird clients should remain "Connected" as traffic is automatically routed to the remaining nodes.

**4. Recovery:**
```bash
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml -m shell -a "cd /opt/netbird && docker-compose start netbird-management"
```

</details>

### HA04 - PgBouncer Failover

<details>
<summary>Failure Simulation</summary>

**1. Stop PgBouncer on Node 1:**
```bash
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml -m shell -a "cd /opt/netbird && docker-compose stop pgbouncer"
```

**2. Verify Management Stability:**
Management Node 1 will lose DB connectivity, but HAProxy will detect the failed health check (since Management depends on PgBouncer) and route traffic to Nodes 2 & 3.

**3. Recovery:**
```bash
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml -m shell -a "cd /opt/netbird && docker-compose start pgbouncer"
```

</details>

</details>

---

## Advanced HA Production Tips

<details open>
<summary>Expand/Collapse</summary>

### 1. Split-Brain Prevention
Always ensure `keepalived` is configured with a dedicated tracking script or interface check to prevent both nodes from claiming the VIP simultaneously.

### 2. Connection Draining
When performing maintenance, use HAProxy "maint" mode to drain connections gracefully before stopping a service:
```bash
echo "disable server netbird_backend/mgmt-1" | sudo socat stdio /var/run/haproxy.sock
```

### 3. Automated Alerting
Configure Prometheus alerts for `haproxy_backend_active_servers < 3`. An HA cluster should never run at reduced capacity without an alert being triggered.

</details>

---

## Appendix

<details>
<summary>Expand/Collapse</summary>

### A. Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](../architecture.md) | HA Design Overview |
| [Monitoring](../operations/monitoring-alerting.md) | Alerting setup |

</details>
