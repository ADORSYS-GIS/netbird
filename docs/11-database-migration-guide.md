# 11 - Database Migration Guide (SQLite to PostgreSQL)

This guide explains how to migrate a production NetBird instance from SQLite to PostgreSQL.

## Prerequisite Check
*   [ ] Current NetBird version >= 0.28.0
*   [ ] Downtime window scheduled (approx. 15-30 mins)
*   [ ] Destination PostgreSQL database ready and accessible
*   [ ] `scripts/migrate-database.sh` is executable

## Migration Procedure

### 1. Backup Existing Data
Always backup before migration.
```bash
cp /var/lib/netbird/store.db /var/lib/netbird/store.db.bak
```

### 2. Prepare Destination Database
Ensure you have the connection string (DSN) for your PostgreSQL database.
Format: `host=postgres.example.com port=5432 dbname=netbird user=netbird password=SECRET sslmode=require`

### 3. Run Migration Script
We provide a helper script that uses NetBird's built-in migration tools.

```bash
sudo ./scripts/migrate-database.sh
```
Follow the interactive prompts to export data and import to Postgres.

### 4. Update Infrastructure Configuration
After successful data migration, update your Infrastructure as Code to reflect the change.

**Edit `infrastructure/terraform.tfvars`**:
```hcl
database_type = "postgresql"
database_mode = "existing"
existing_postgresql_host = "postgres.example.com"
# ... other connection details
```

**Apply Changes**:
```bash
cd infrastructure
terraform apply
```

### 5. Redeploy Application
Reconfigure the NetBird server to use the new backend.

```bash
cd ../configuration
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

### 6. Verification
Check logs to ensure NetBird connected to Postgres:
```bash
docker logs netbird-server | grep "Connected to PostgreSQL"
```

## Troubleshooting

### "Error: UNIQUE constraint failed"
If import fails with constraint errors, ensure the target database is **empty** before importing.
```sql
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

### "Connection Refused"
Check Security Groups / Firewall rules on the Database Server to allow access from the Management Node IP.
