# Database Configuration

## Backend Selection

NetBird supports two database backends:

| Backend | Use Case | Max Peers |
|---------|----------|-----------|
| SQLite | Single-instance, simple deployments | ~1000 |
| PostgreSQL | Multi-instance HA, large deployments | Unlimited |

## Configuration

### SQLite (Default)

```yaml
# inventory/group_vars/all.yml
netbird_database_backend: "sqlite"
netbird_sqlite_datadir: "/var/lib/netbird"
```

### PostgreSQL Container

```yaml
# inventory/group_vars/all.yml
netbird_database_backend: "postgres"
netbird_postgres_host: "postgres"
netbird_postgres_port: 5432
netbird_postgres_database: "netbird"
netbird_postgres_user: "netbird"
netbird_postgres_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          ...encrypted...
```

### External PostgreSQL HA

```yaml
# inventory/group_vars/all.yml
netbird_database_backend: "postgres"
netbird_postgres_host: "postgres-ha.internal.example.com"
netbird_postgres_sslmode: "require"
```

## Migration

### SQLite → PostgreSQL

```mermaid
graph LR
    A[Stop NetBird] --> B[Backup SQLite DB]
    B --> C[Update group_vars]
    C --> D[Run Playbook]
    D --> E[Verify PostgreSQL]
    E --> F[Migrate Data]
```

**Steps**:

1. Stop NetBird stack
2. Backup SQLite database
3. Update `netbird_database_backend: "postgres"`
4. Re-run playbook
5. Use NetBird migration tools to transfer data

## Technical Specification

**Version**: 1.0  
**Last Audit**: 2026-02-15
