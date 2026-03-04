# Disaster Recovery

Comprehensive guide for backup and restoration procedures for the NetBird HA stack.

## Overview

<details open>
<summary>Disaster Recovery Workflow</summary>

```
┌──────────────────────────────────────────────────────────────┐
│                  DISASTER RECOVERY WORKFLOW                  │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ Backup Process  │
    │ Automated DB    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Point-in-Time   │
    │ Cloud Restore   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Recovery Proc   │
    │ 3-Node Resync   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Testing         │
    │ Quarterly Drill │
    └─────────────────┘
```

### Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** | 1 Hour | Time to full service recovery |
| **RPO** | 24 Hours | Maximum data loss window |
| **Retention** | 30 Days | Production backup storage |

</details>

## Procedures

<details open>
<summary>Disaster Recovery Implementation</summary>

### Database Backups (PostgreSQL)

<details>
<summary>Execution Details</summary>

**1. Verify Automated Backups (AWS RDS):**
```bash
aws rds describe-db-instances \
  --db-instance-identifier netbird-db \
  --query 'DBInstances[0].{Backup:BackupRetentionPeriod,Window:PreferredBackupWindow}'
```

**2. Manual On-Demand Backup:**
```bash
# Create backup before infrastructure changes
pg_dump -h db.example.com -U netbird -d netbird | gzip > netbird-backup-$(date +%Y%m%d).sql.gz
```

</details>

### Point-in-Time Recovery (PITR)

<details>
<summary>Execution Details</summary>

**1. Restore Instance from Snapshot:**
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier netbird-db-restored \
  --db-snapshot-identifier rds:netbird-db-2026-02-16-03-00 \
  --db-instance-class db.t3.medium
```

**2. Update Infrastructure Config:**
Update `terraform.tfvars` with the new endpoint and run:
```bash
terraform apply
```

</details>

### 3-Node Cluster Recovery

<details>
<summary>Execution Details</summary>

**1. Re-provision Corrupted Node:**
```bash
terraform apply -replace="module.inventory.management_nodes[\"node-id\"]"
```

**2. Verify Resync:**
The node will automatically sync state via port `9090`. Check status:
```bash
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker logs netbird-management | grep cluster"
```

</details>

### Quarterly DR Drill

<details>
<summary>Verification Details</summary>

| Step | Verification Command | Expected Output |
|------|----------------------|-----------------|
| Backup | `ls -lh /tmp/dr-test.sql` | Size > 0 |
| Restore | `psql -d dr_test -c "SELECT 1"` | `1` |
| Sync | `netbird status` | `Connected` |

</details>

</details>

## Related Documentation

<details>
<summary>Additional Resources</summary>

| Document | Description |
|----------|-------------|
| [Architecture](../architecture.md) | HA Design |
| [Monitoring](./monitoring-alerting.md) | Backup Alerts |

</details>
