# Troubleshooting & Restoration (Ansible Stack)

**Recovery and Incident Response Procedures**

## Disaster Recovery Procedures

### Database Backups (PostgreSQL)

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

### Point-in-Time Recovery (PITR)

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

### 3-Node Cluster Recovery

**1. Re-provision Corrupted Node:**
```bash
terraform apply -replace="module.inventory.management_nodes[\"node-id\"]"
```

**2. Verify Resync:**
The node will automatically sync state via port `9090`. Check status:
```bash
ansible management -i inventory/terraform_inventory.yaml -m shell -a "docker logs netbird-management | grep cluster"
```

### Quarterly DR Drill

| Step | Verification Command | Expected Output |
|------|----------------------|-----------------|
| Backup | `ls -lh /tmp/dr-test.sql` | Size > 0 |
| Restore | `psql -d dr_test -c "SELECT 1"` | `1` |
| Sync | `netbird status` | `Connected` |
