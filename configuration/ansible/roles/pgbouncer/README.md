# PgBouncer Connection Pooler Role

This Ansible role deploys and configures PgBouncer, a lightweight connection pooler for PostgreSQL.

## Purpose

PgBouncer sits between NetBird management servers and PostgreSQL, preventing connection exhaustion under load by:
- Pooling database connections (default: 25 per management node)
- Using transaction-mode pooling (connections released after each transaction)
- Supporting 1000+ client connections with only 25-30 pooled database connections
- Implementing automatic connection timeout and health checks

## Critical for HA

Without PgBouncer:
- Each management node opens unlimited connections to PostgreSQL
- With 2+ nodes under load, connections exhaust quickly
- Database becomes unavailable → entire cluster fails

With PgBouncer:
- Connections are pooled and reused
- Prevents exhaustion and cascading failures
- Supports true multi-node HA

## Architecture

```
Client Connections (1000s)
         ↓↓↓
┌─────────────────────┐
│    PgBouncer        │ (port 6432)
│  25 pooled conns    │
└──────────┬──────────┘
           ↓
    PostgreSQL DB
```

## Variables

### Critical Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `pgbouncer_listen_port` | 6432 | Port PgBouncer listens on |
| `pgbouncer_database_host` | localhost | PostgreSQL host IP/DNS |
| `pgbouncer_database_port` | 5432 | PostgreSQL port |
| `pgbouncer_database_name` | netbird_db | Database name |
| `pgbouncer_database_user` | netbird_user | Database user |
| `pgbouncer_database_password` | (required) | Database password |
| `pgbouncer_database_sslmode` | require | SSL mode (require, prefer, disable) |

### Pool Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `pgbouncer_pool_mode` | transaction | Mode: session, transaction, statement |
| `pgbouncer_min_pool_size` | 10 | Minimum idle connections per DB |
| `pgbouncer_default_pool_size` | 25 | Target pool size (tuned for 2-3 mgmt nodes) |
| `pgbouncer_reserve_pool_size` | 5 | Extra connections for spikes |
| `pgbouncer_max_client_conn` | 1000 | Max client connections |
| `pgbouncer_max_db_connections` | 100 | Max connections per DB |

### Timeout Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `pgbouncer_server_lifetime` | 3600 | Max connection age (seconds) |
| `pgbouncer_server_idle_timeout` | 600 | Idle timeout (seconds) |
| `pgbouncer_client_idle_timeout` | 900 | Client idle timeout (seconds) |
| `pgbouncer_query_timeout` | 0 | Query timeout (0 = unlimited) |
| `pgbouncer_query_wait_timeout` | 120 | Max wait for free pool slot |

## Usage

### In Playbook

```yaml
- name: Deploy NetBird with Connection Pooling
  hosts: management
  become: true
  roles:
    - common
    - pgbouncer  # ← Deploy BEFORE management services!
    - netbird-management
    - netbird-signal
    - netbird-dashboard
```

### In terraform.tfvars

```hcl
# Enable PgBouncer connection pooler
enable_pgbouncer              = true
pgbouncer_default_pool_size   = 25
pgbouncer_pool_mode           = "transaction"
```

## Health Check

PgBouncer includes a Docker health check that verifies connectivity:

```bash
# Manual test
docker exec pgbouncer psql -h localhost -p 6432 -U netbird_user -d netbird_db -c "SELECT 1;"

# Or via HAProxy health check
# curl http://localhost:6432/  (if stats are exposed)
```

## Monitoring

### View Pool Statistics

```bash
# Connect to PgBouncer admin
psql -h localhost -p 6432 -U postgres -d pgbouncer

# Show active pools
SHOW POOLS;

# Show client connections
SHOW CLIENTS;

# Show server connections
SHOW SERVERS;

# Show database stats
SHOW STATS;
```

### Key Metrics to Monitor

- `active_connections` - Currently active DB connections (should stay ≤ 25)
- `idle_connections` - Idle connections in pool (good: 10-20)
- `waiting_clients` - Clients waiting for connection (0 = healthy)
- `avg_query_time` - Average query time (should be <50ms with pooling)

### Prometheus Metrics (if enabled)

- `pgbouncer_pools_clients_active` - Active client connections
- `pgbouncer_pools_servers_active` - Active DB connections
- `pgbouncer_pools_servers_idle` - Idle DB connections

## Troubleshooting

### Issue: "too many connections"

**Symptom**: PostgreSQL rejects new connections

**Cause**: PgBouncer pool exhausted or misconfigured

**Solution**:
```bash
# Check current connections
docker exec pgbouncer psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"

# Increase pool size in defaults/main.yml
pgbouncer_default_pool_size: 35  # Increase from 25

# Restart PgBouncer
ansible-playbook playbooks/site.yml --tags pgbouncer
```

### Issue: Slow queries with PgBouncer

**Cause**: Transaction mode overhead or connection reuse issues

**Solution**:
```bash
# Verify pool mode is 'transaction'
grep "pool_mode" /etc/pgbouncer/pgbouncer.ini

# Check for connection issues
docker logs pgbouncer | tail -50

# Increase server_lifetime if needed
pgbouncer_server_lifetime: 7200  # Default 3600s
```

### Issue: PgBouncer container won't start

**Solution**:
```bash
# Check logs
docker logs pgbouncer

# Verify configuration
cat /etc/pgbouncer/pgbouncer.ini

# Check database connectivity
docker exec pgbouncer psql -h <db_host> -U <db_user> -d <db_name> -c "SELECT 1;"

# Restart
systemctl restart pgbouncer  # or docker restart pgbouncer
```

## Performance Tuning

### For 2 Management Nodes

```yaml
pgbouncer_default_pool_size: 25   # 50 conns / 2 nodes = 25 per
pgbouncer_min_pool_size: 10
pgbouncer_reserve_pool_size: 5
pgbouncer_pool_mode: "transaction"
```

### For 3+ Management Nodes

```yaml
pgbouncer_default_pool_size: 20   # 60 conns / 3 nodes = 20 per
pgbouncer_min_pool_size: 8
pgbouncer_reserve_pool_size: 4
pgbouncer_pool_mode: "transaction"
```

### For High Throughput (10,000+ reqs/sec)

```yaml
pgbouncer_default_pool_size: 35
pgbouncer_max_client_conn: 2000
pgbouncer_query_timeout: 0         # Unlimited
pgbouncer_server_lifetime: 7200    # Longer lifetime
```

## Deployment Checklist

- [ ] Database credentials configured in terraform.tfvars
- [ ] PgBouncer port (6432) open in firewall between nodes and pooler
- [ ] PostgreSQL accessible from PgBouncer container
- [ ] Connection pool size calculated for your setup
- [ ] Health checks passing: `docker logs pgbouncer`
- [ ] Database connections pooled: `SHOW POOLS;` shows active ≤ 25
- [ ] Management services configured to use PgBouncer (port 6432)
- [ ] Monitoring configured to track pool statistics

## Integration with Management Services

Management containers must be configured to connect to PgBouncer instead of direct PostgreSQL:

**Before (Single Node)**:
```
NETBIRD_STORE_ENGINE_POSTGRES_DSN="postgres://user:pass@db.example.com:5432/netbird"
```

**After (With PgBouncer)**:
```
NETBIRD_STORE_ENGINE_POSTGRES_DSN="postgres://user:pass@localhost:6432/netbird"
```

The role automatically updates this in the inventory when enabled.

## References

- PgBouncer Docs: https://www.pgbouncer.org/config.html
- Pool Mode Comparison: https://www.pgbouncer.org/usage.html#pool-mode
- Best Practices: https://www.pgbouncer.org/config.html#administrative-functions
