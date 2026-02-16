# Disaster Recovery

Comprehensive backup and recovery procedures for NetBird infrastructure.

## Recovery Objectives

- **RTO (Recovery Time Objective)**: 1 hour for full system recovery
- **RPO (Recovery Point Objective)**: 24 hours maximum data loss (daily backups)
- **Backup Retention**: 30 days for production, 7 days for staging

## Backup Strategy

### Database Backups

#### PostgreSQL (Recommended)

**Automated Cloud Backups**:

- **AWS RDS**:
  ```bash
  # Verify automated backups are enabled
  aws rds describe-db-instances \
    --db-instance-identifier netbird-db \
    --query 'DBInstances[0].{Backup:BackupRetentionPeriod,Window:PreferredBackupWindow}'
  ```
  
  **Expected output**:
  ```json
  {
    "Backup": 7,
    "Window": "03:00-04:00"
  }
  ```

- **GCP Cloud SQL**:
  ```bash
  # Check backup configuration
  gcloud sql instances describe netbird-db \
    --format="table(settings.backupConfiguration.enabled,settings.backupConfiguration.startTime)"
  ```
  
  **Expected output**:
  ```
  ENABLED  START_TIME
  True     03:00
  ```

- **Azure Database**:
  ```bash
  # Verify backup retention
  az postgres server show \
    --resource-group netbird-rg \
    --name netbird-db \
    --query '{retention:storageProfile.backupRetentionDays}'
  ```

**Manual Database Backup**:

```bash
# Create on-demand backup before major changes
ssh management-node

# PostgreSQL backup
pg_dump -h db.example.com -U netbird -d netbird > netbird-backup-$(date +%Y%m%d-%H%M%S).sql

# Compress backup
gzip netbird-backup-*.sql

# Upload to S3 (or your backup location)
aws s3 cp netbird-backup-*.sql.gz s3://netbird-backups/manual/
```

**Expected output**:
```
upload: ./netbird-backup-20260216-143000.sql.gz to s3://netbird-backups/manual/netbird-backup-20260216-143000.sql.gz
```

#### SQLite

**Backup SQLite database**:

```bash
ssh management-node

# Stop NetBird service
cd /opt/netbird
docker-compose stop netbird-management

# Backup database file
cp /var/lib/netbird/store.db /var/lib/netbird/store.db.backup-$(date +%Y%m%d)

# Restart service
docker-compose start netbird-management
```

**Verify backup**:
```bash
ls -lh /var/lib/netbird/store.db*
```

**Expected output**:
```
-rw-r--r-- 1 root root  24M Feb 16 14:30 store.db
-rw-r--r-- 1 root root  24M Feb 16 14:30 store.db.backup-20260216
```

### Configuration Backups

#### Terraform State

**State is automatically versioned** in remote backend:

```bash
# List state versions (S3 backend)
aws s3api list-object-versions \
  --bucket netbird-terraform-state \
  --prefix prod/terraform.tfstate \
  --query 'Versions[*].[VersionId,LastModified]' \
  --output table
```

**Backup terraform.tfvars** (contains sensitive configuration):

```bash
# Encrypt and backup
cd infrastructure/ansible-stack
gpg -c terraform.tfvars

# Store encrypted copy securely
aws s3 cp terraform.tfvars.gpg s3://netbird-secure-backups/
```

#### Application Configuration

```bash
# Backup all NetBird configuration files
ssh management-node
tar -czf netbird-config-backup-$(date +%Y%m%d).tar.gz \
  /opt/netbird/ \
  /etc/caddy/ \
  /var/lib/netbird/

# Upload to backup location
scp netbird-config-backup-*.tar.gz backup-server:/backups/
```

### Secrets Backup

**Critical**: Store encrypted copies of:
- Terraform tfvars files
- SSH private keys
- Keycloak admin credentials
- Database credentials

```bash
# Create encrypted secrets backup
tar -czf secrets-backup.tar.gz \
  terraform.tfvars \
  ~/.ssh/netbird-key.pem

# Encrypt with GPG
gpg -c secrets-backup.tar.gz

# Store in secure location (1Password, AWS Secrets Manager, etc.)
```

## Restore Procedures

### Scenario 1: Database Point-in-Time Recovery (PITR)

**When to use**: Data corruption, accidental deletion, or need to recover to specific timestamp.

**Recovery Steps**:

1. **Identify Recovery Point**:
   ```bash
   # Check when corruption occurred
   # For AWS RDS, find last good backup
   aws rds describe-db-snapshots \
     --db-instance-identifier netbird-db \
     --query 'DBSnapshots[].[DBSnapshotIdentifier,SnapshotCreateTime]' \
     --output table
   ```

2. **Create Test Instance from Snapshot**:
   ```bash
   # AWS RDS - Restore to new instance
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier netbird-db-restored \
     --db-snapshot-identifier rds:netbird-db-2026-02-16-03-00 \
     --db-instance-class db.t3.medium
   
   # Wait for instance to be available
   aws rds wait db-instance-available \
     --db-instance-identifier netbird-db-restored
   ```
   
   **Expected output**:
   ```
   Waiting for db-instance-available... (this may take 5-10 minutes)
   ```

3. **Verify Restored Data**:
   ```bash
   # Connect to restored instance
   psql -h netbird-db-restored.xxx.rds.amazonaws.com -U netbird -d netbird
   
   # Verify data integrity
   SELECT COUNT(*) FROM users;
   SELECT COUNT(*) FROM peers;
   ```

4. **Switch to Restored Database**:
   ```bash
   # Update terraform.tfvars with new database endpoint
   cd infrastructure/ansible-stack
   nano terraform.tfvars
   # Update: existing_postgresql_host = "netbird-db-restored.xxx.rds.amazonaws.com"
   
   terraform apply
   
   # Redeploy NetBird with new database
   cd ../../configuration/ansible
   ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
   ```

5. **Verify Services**:
   ```bash
   curl https://netbird.yourdomain.com/health
   ```
   
   **Expected output**:
   ```json
   {"status":"ok"}
   ```

6. **Delete Old Database** (after verification):
   ```bash
   # Only after confirming everything works
   aws rds delete-db-instance \
     --db-instance-identifier netbird-db \
     --skip-final-snapshot
   ```

### Scenario 2: Manual Database Restore from Backup

**When to use**: Restore from manual backup file.

**Recovery Steps**:

1. **Download Backup**:
   ```bash
   # From S3 or backup location
   aws s3 cp s3://netbird-backups/manual/netbird-backup-20260216-143000.sql.gz .
   
   # Decompress
   gunzip netbird-backup-20260216-143000.sql.gz
   ```

2. **Stop NetBird Services**:
   ```bash
   ssh management-node
   cd /opt/netbird
   docker-compose stop netbird-management netbird-signal
   ```

3. **Restore Database**:
   ```bash
   # Drop and recreate database (CAUTION!)
   psql -h db.example.com -U netbird -d postgres <<EOF
   DROP DATABASE IF EXISTS netbird;
   CREATE DATABASE netbird;
   \q
   EOF
   
   # Restore from backup
   psql -h db.example.com -U netbird -d netbird < netbird-backup-20260216-143000.sql
   ```
   
   **Expected output**:
   ```
   SET
   SET
   CREATE TABLE
   ...
   COPY 150
   ```

4. **Restart Services**:
   ```bash
   docker-compose start netbird-management netbird-signal
   
   # Verify logs
   docker-compose logs -f --tail=50
   ```

5. **Verify Recovery**:
   ```bash
   # Test health endpoint
   curl http://localhost:80/health
   
   # Check dashboard
   curl https://netbird.yourdomain.com
   ```

### Scenario 3: Full Infrastructure Redeployment

**When to use**: Complete region failure, disaster recovery drill, or migrating infrastructure.

**Estimated Time**: 30-60 minutes

**Pre-requisites**:
- Access to terraform.tfvars backup
- Access to database backup
- SSH keys available
- DNS access to update records

**Recovery Steps**:

1. **Prepare New Environment**:
   ```bash
   git clone https://github.com/yourorg/netbird-infrastructure.git
   cd netbird-infrastructure/infrastructure/ansible-stack
   
   # Restore terraform.tfvars
   gpg -d terraform.tfvars.gpg > terraform.tfvars
   ```

2. **Update Configuration for New Region** (if necessary):
   ```bash
   nano terraform.tfvars
   # Change region if needed:
   # aws_region = "us-west-2"  # New region
   ```

3. **Deploy Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```
   
   **Expected duration**: 10-15 minutes
   
   **Expected output**:
   ```
   Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
   
   Outputs:
   reverse_proxy_public_ip = "54.x.x.x"
   ```

4. **Update DNS**:
   ```bash
   # Update A record for netbird.yourdomain.com
   # Point to new reverse_proxy_public_ip
   
   # Verify DNS propagation
   dig netbird.yourdomain.com +short
   ```

5. **Restore Database** (if not using managed service):
   ```bash
   # Follow "Manual Database Restore" steps above
   ```

6. **Deploy Application**:
   ```bash
   cd ../../configuration/ansible
   ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
   ```
   
   **Expected duration**: 5-10 minutes

7. **Verification**:
   ```bash
   # Health check
   curl -f https://netbird.yourdomain.com/health
   
   # Complete security validation
   ansible-playbook -i inventory/terraform_inventory.yaml playbooks/validate-security.yml
   ```
   
   **Expected output**:
   ```
   PLAY RECAP *****************************************************
   management-node   : ok=10   changed=0   unreachable=0   failed=0
   reverse-proxy     : ok=8    changed=0   unreachable=0   failed=0
   ```

8. **Test Client Connectivity**:
   ```bash
   # On a test client
   netbird up
   netbird status
   ```

### Scenario 4: Configuration Restore Only

**When to use**: Configuration drift, accidental changes, or rollback needed.

**Recovery Steps**:

1. **Download Configuration Backup**:
   ```bash
   scp backup-server:/backups/netbird-config-backup-20260216.tar.gz .
   tar -xzf netbird-config-backup-20260216.tar.gz
   ```

2. **Restore Configuration**:
   ```bash
   ssh management-node
   
   # Stop services
   cd /opt/netbird
   docker-compose down
   
   # Restore configuration
   sudo rsync -av netbird-config-backup/opt/netbird/ /opt/netbird/
   sudo rsync -av netbird-config-backup/etc/caddy/ /etc/caddy/
   
   # Restart services
   docker-compose up -d
   ```

3. **Verify**:
   ```bash
   docker-compose ps
   curl http://localhost:80/health
   ```

## Disaster Recovery Testing

### Quarterly DR Drill

**Schedule**: Perform full DR test quarterly.

**Automated DR Test Script**:

```bash
#!/bin/bash
# scripts/dr-test.sh - Disaster Recovery Test

set -e

echo "=== NetBird Disaster Recovery Test ==="
echo "Starting DR test at $(date)"

# 1. Create test backup
echo "Step 1: Creating test backup..."
ssh management-node "cd /opt/netbird && docker-compose exec -T postgres pg_dump -U netbird netbird > /tmp/dr-test-backup.sql"

# 2. Verify backup
echo "Step 2: Verifying backup file..."
ssh management-node "ls -lh /tmp/dr-test-backup.sql"

# 3. Test restore to temporary database
echo "Step 3: Testing restore..."
ssh management-node "psql -h db.example.com -U netbird -d postgres -c 'CREATE DATABASE dr_test'"
ssh management-node "psql -h db.example.com -U netbird -d dr_test < /tmp/dr-test-backup.sql"

# 4. Verify restored data
echo "Step 4: Verifying restored data..."
ORIGINAL_COUNT=$(ssh management-node "psql -h db.example.com -U netbird -d netbird -t -c 'SELECT COUNT(*) FROM users'")
RESTORED_COUNT=$(ssh management-node "psql -h db.example.com -U netbird -d dr_test -t -c 'SELECT COUNT(*) FROM users'")

if [ "$ORIGINAL_COUNT" == "$RESTORED_COUNT" ]; then
  echo "✓ Data verification successful: $RESTORED_COUNT users"
else
  echo "✗ Data verification failed!"
  exit 1
fi

# 5. Cleanup
echo "Step 5: Cleaning up test resources..."
ssh management-node "psql -h db.example.com -U netbird -d postgres -c 'DROP DATABASE dr_test'"
ssh management-node "rm /tmp/dr-test-backup.sql"

echo "=== DR Test Complete at $(date) ==="
echo "Result: SUCCESS"
```

**Run the test**:
```bash
chmod +x scripts/dr-test.sh
./scripts/dr-test.sh
```

**Expected output**:
```
=== NetBird Disaster Recovery Test ===
Starting DR test at Sat Feb 16 14:30:00 UTC 2026
Step 1: Creating test backup...
Step 2: Verifying backup file...
-rw-r--r-- 1 ubuntu ubuntu 24M Feb 16 14:30 /tmp/dr-test-backup.sql
Step 3: Testing restore...
Step 4: Verifying restored data...
✓ Data verification successful: 150 users
Step 5: Cleaning up test resources...
=== DR Test Complete at Sat Feb 16 14:35:00 UTC 2026 ===
Result: SUCCESS
```

## Recovery Time Estimates

| Scenario | Estimated RTO | Complexity |
|----------|---------------|------------|
| Database PITR (AWS RDS) | 15-30 min | Low |
| Manual DB Restore | 10-20 min | Low |
| Configuration Restore | 5-10 min | Low |
| Full Infrastructure Redeployment | 30-60 min | Medium |
| Cross-Region Failover | 45-90 min | High |

## Related Documentation

- [Security Hardening](./security-hardening.md)
- [Monitoring and Alerting](./monitoring-alerting.md)
