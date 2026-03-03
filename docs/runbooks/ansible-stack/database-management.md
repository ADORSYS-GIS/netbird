# Database HA & Pooling Runbook

Procedures for managing PostgreSQL connection pooling via PgBouncer and maintaining database availability in a high-load environment.

[[_TOC_]]

## Overview

<details open>
<summary>Expand/Collapse</summary>

```
┌──────────────────────────────────────────────────────────────┐
│                  DATABASE HA & POOLING WORKFLOW               │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ DB01 - MONITOR  │
    │ Check Stats     │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ DB02 - MAINTAIN │
    │ Drain & Pause   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ DB03 - OPTIMIZE │
    │ Tune Pool Size  │
    └─────────────────┘
```

### Core Components

| Layer | Component | Technology | Role |
|-------|-----------|------------|------|
| **Pooling** | PgBouncer | Docker Container | Transaction-level pooling |
| **Backend** | PostgreSQL | Managed RDS/CloudSQL | HA Primary/Replica Storage |

</details>

---

## Operations

<details open>
<summary>Expand/Collapse</summary>

### DB01 - Connection Verification

<details>
<summary>Execution Details</summary>

**1. Test PgBouncer Listener (Port 6432):**
```bash
# Verify connectivity from a management node
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U netbird -d netbird -c 'SELECT 1;'"
```

**2. Inspect Connection Pools:**
```bash
# Check how many connections are active vs waiting
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS;'"
```

**Expected Result:**
`cl_waiting` should ideally be `0`. If `cl_waiting` is consistently high, the pool size needs to be increased.

</details>

### DB02 - Maintenance (Draining Traffic)

<details>
<summary>Execution Details</summary>

When performing maintenance on the backend PostgreSQL instance (e.g., version upgrades or rebooting for parameter changes), use PgBouncer to pause the application traffic without dropping existing sessions:

**1. Pause Connections:**
```bash
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c 'PAUSE netbird;'"
```

**2. Perform Maintenance:**
Execute your cloud provider's maintenance task (RDS Upgrade, etc.).

**3. Resume Traffic:**
```bash
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c 'RESUME netbird;'"
```

</details>

### DB03 - Pool Tuning

<details>
<summary>Execution Details</summary>

If you scale the management cluster beyond 3 nodes, you must update the pooling limits in `terraform.tfvars`:

```hcl
pgbouncer_default_pool_size = 50  # Increase if cl_waiting > 0
pgbouncer_max_client_conn   = 2000
```

**Apply Changes:**
```bash
terraform apply
```

</details>

</details>

---

## Best Practices

<details open>
<summary>Expand/Collapse</summary>

### 1. Pooling Mode
The NetBird HA stack is configured for **transaction pooling**. This allows a single backend connection to be reused by multiple management node requests as soon as the transaction finishes, maximizing scalability.

### 2. Monitoring
Always watch the `pgbouncer_pools_client_waiting_connections` metric in Prometheus. Any value above 0 indicates that requests are being delayed because the connection pool is saturated.

</details>

---

## Appendix

<details>
<summary>Expand/Collapse</summary>

### A. Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](../architecture.md) | HA Design Overview |
| [Disaster Recovery](../../operations-book/disaster-recovery.md) | Backup & Restore procedures |

</details>

