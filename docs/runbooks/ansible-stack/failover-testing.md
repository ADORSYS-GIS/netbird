# High Availability Failover Testing

Procedures for testing and verifying high availability and failover mechanisms in NetBird production clusters.

## Table of Contents

- [Overview](#overview)
- [Pre-Test Checklist](#pre-test-checklist)
- [Failover Test Procedures](#failover-test-procedures)
- [Verification](#verification)
- [Best Practices](#best-practices)

---

## Overview

<details open>
<summary>Expand/Collapse Overview</summary>

### HA Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  HA FAILOVER TESTING WORKFLOW                │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │  Network Layer  │
    │  VIP Failover   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Traffic Layer  │
    │  Load Balancer  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   App Layer     │
    │  Management     │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   Data Layer    │
    │ PgBouncer / DB  │
    └─────────────────┘
```

### Failure Domains

A production-ready HA cluster must be regularly tested for failure scenarios across four primary domains:

| Domain | Component | Expected Recovery Time | Impact |
|--------|-----------|----------------------|--------|
| **Network** | DNS/Load Balancer | Varies by provider | Traffic routes to healthy nodes |
| **Traffic** | HAProxy Service | Instant | Traffic routes to healthy proxy |
| **Application** | Management Node | < 5 seconds | Traffic routes to healthy nodes |
| **Data** | PgBouncer Pooler | < 10 seconds | Connections route to healthy nodes |

### Testing Frequency

- **Production**: Quarterly (every 3 months)
- **Staging**: Monthly
- **After Changes**: After any HA configuration changes

</details>

---

## Pre-Test Checklist

<details open>
<summary>Expand/Collapse Checklist</summary>

Before conducting failover tests:

- [ ] **Maintenance Window Scheduled**
  - Stakeholders notified
  - Change request approved
  - Rollback plan prepared

- [ ] **Baseline Health Verified**
  - All services running normally
  - No active incidents
  - Monitoring shows green status
  - Recent backups completed

- [ ] **Test Environment Prepared**
  - Test clients ready
  - Monitoring dashboards open
  - Communication channels active
  - Documentation accessible

- [ ] **Team Ready**
  - Primary operator identified
  - Observer assigned
  - Communication plan established
  - Escalation path defined

**STOP IF**:
- Active incidents exist
- Recent configuration changes not tested
- Backup failed
- Monitoring unavailable

</details>

---

## Failover Test Procedures

### Test 1: HAProxy Node Failure

<details open>
<summary>Expand/Collapse HAProxy Failover Test</summary>

**Objective**: Verify traffic routes to healthy HAProxy nodes when one fails

**Duration**: 5-10 minutes

**Impact**: Minimal (DNS/LB handles failover)

#### Step 1: Identify Active Nodes

```bash
# Check all HAProxy nodes
ansible reverse_proxy -i inventory/terraform_inventory.yaml \
  -m shell -a "docker ps | grep haproxy"

# Check HAProxy stats on all nodes
for node in $(ansible reverse_proxy -i inventory/terraform_inventory.yaml --list-hosts | tail -n +2); do
  echo "=== $node ==="
  curl -s http://$node:8404/stats
done
```

**Expected**: All nodes show HAProxy running

#### Step 2: Document Current State

```bash
# Record current state
echo "Testing HAProxy failover at $(date)" >> failover-test-log.txt

# Check HAProxy stats
curl -s https://your-domain.com:8404/stats > haproxy-before.txt
```

#### Step 3: Stop HAProxy on One Node

```bash
# Stop HAProxy service on one node
ansible <test-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "docker stop haproxy"

# Record time
date >> failover-test-log.txt
```

#### Step 4: Monitor Traffic Routing

```bash
# Test API access (should continue working via other nodes)
for i in {1..10}; do
  curl -f https://your-domain.com/health && echo "Success $i" || echo "Failed $i"
  sleep 1
done

# Record time
date >> failover-test-log.txt
```

**Expected**: All requests succeed (routed to healthy nodes)

#### Step 5: Verify Service Continuity

```bash
# Test API access
curl -f https://your-domain.com/health

# Check client connectivity
netbird status  # On test client

# Verify no dropped connections
```

**Expected**: No service interruption

#### Step 6: Restore Node

```bash
# Restart HAProxy
ansible <test-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "docker start haproxy"

# Verify node is healthy
sleep 10
ansible <test-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "docker ps | grep haproxy"
```

#### Step 7: Document Results

```bash
# Record test completion
echo "Test completed successfully" >> failover-test-log.txt
date >> failover-test-log.txt
```

</details>

### Test 2: HAProxy Service Failure

<details>
<summary>Expand/Collapse HAProxy Failover Test</summary>

**Objective**: Verify traffic routes to backup when HAProxy fails

**Duration**: 5-10 minutes

**Impact**: Brief connection interruption possible

#### Step 1: Baseline Check

```bash
# Check HAProxy status on all nodes
ansible reverse_proxy -i inventory/terraform_inventory.yaml \
  -m shell -a "systemctl status haproxy"

# Check current stats
curl -s https://your-domain.com:8404/stats > haproxy-baseline.txt
```

#### Step 2: Stop HAProxy on Active Node

```bash
# Stop HAProxy service
ansible <active-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "sudo systemctl stop haproxy"

# Record time
date >> failover-test-log.txt
```

#### Step 3: Verify VIP Migration

```bash
# If using track_script, VIP should move immediately
ansible reverse_proxy -i inventory/terraform_inventory.yaml \
  -m shell -a "ip addr show | grep -E 'inet.*scope global'"
```

**Expected**: VIP moves to node with healthy HAProxy

#### Step 4: Test Service Access

```bash
# Test API (should work immediately)
curl -f https://your-domain.com/health

# Test dashboard
curl -I https://your-domain.com

# Check client status
netbird status
```

**Expected**: All services accessible

#### Step 5: Restore HAProxy

```bash
# Start HAProxy
ansible <active-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "sudo systemctl start haproxy"

# Verify service started
ansible <active-proxy-node> -i inventory/terraform_inventory.yaml \
  -m shell -a "systemctl status haproxy"
```

#### Step 6: Verify Full Recovery

```bash
# Check all backends healthy
curl -s https://your-domain.com:8404/stats | grep -i backend

# Verify VIP distribution
ansible reverse_proxy -i inventory/terraform_inventory.yaml \
  -m shell -a "ip addr show | grep -E 'inet.*scope global'"
```

</details>

### Test 3: Management Node Failure

<details>
<summary>Expand/Collapse Management Node Failover Test</summary>

**Objective**: Verify traffic routes to healthy management nodes

**Duration**: 10-15 minutes

**Impact**: None (transparent to users in HA setup)

#### Step 1: Baseline Health Check

```bash
# Check all management nodes
ansible management -i inventory/terraform_inventory.yaml \
  -m shell -a "docker ps | grep netbird-management"

# Check HAProxy backend status
curl -s https://your-domain.com:8404/stats | grep netbird_backend
```

**Expected**: All nodes show UP in HAProxy

#### Step 2: Stop Management on Node 1

```bash
# Stop management service
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "cd /opt/netbird && docker-compose stop netbird-management"

# Record time
date >> failover-test-log.txt
```

#### Step 3: Monitor HAProxy Detection

```bash
# Watch HAProxy detect failure (should be < 5 seconds)
watch -n 1 'curl -s https://your-domain.com:8404/stats | grep <mgmt-node-1>'
```

**Expected**: Node 1 shows DOWN in HAProxy within 5 seconds

#### Step 4: Verify Service Continuity

```bash
# Test API access
for i in {1..10}; do
  curl -f https://your-domain.com/health
  sleep 1
done

# Check client connectivity
netbird status

# Verify peers can still communicate
ping <peer-ip>
```

**Expected**: No service interruption, all requests succeed

#### Step 5: Check Load Distribution

```bash
# Verify traffic goes to nodes 2 and 3
curl -s https://your-domain.com:8404/stats | grep netbird_backend
```

**Expected**: Traffic distributed across healthy nodes only

#### Step 6: Restore Node 1

```bash
# Start management service
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "cd /opt/netbird && docker-compose start netbird-management"

# Wait for health check to pass
sleep 10

# Verify node is UP
curl -s https://your-domain.com:8404/stats | grep <mgmt-node-1>
```

**Expected**: Node 1 returns to UP status

#### Step 7: Verify Load Rebalancing

```bash
# Check traffic distributes across all 3 nodes
curl -s https://your-domain.com:8404/stats | grep netbird_backend
```

</details>

### Test 4: PgBouncer Failure

<details>
<summary>Expand/Collapse PgBouncer Failover Test</summary>

**Objective**: Verify management node fails health check when PgBouncer fails

**Duration**: 10-15 minutes

**Impact**: One management node temporarily unavailable

#### Step 1: Baseline Database Connectivity

```bash
# Check PgBouncer on all nodes
ansible management -i inventory/terraform_inventory.yaml \
  -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS;'"
```

**Expected**: All nodes show healthy pools

#### Step 2: Stop PgBouncer on Node 1

```bash
# Stop PgBouncer
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "cd /opt/netbird && docker-compose stop pgbouncer"

# Record time
date >> failover-test-log.txt
```

#### Step 3: Monitor Management Health Check

```bash
# Management should fail health check within 10 seconds
watch -n 1 'curl -s https://your-domain.com:8404/stats | grep <mgmt-node-1>'
```

**Expected**: Node 1 shows DOWN in HAProxy

#### Step 4: Verify Service Continuity

```bash
# Test API access
curl -f https://your-domain.com/health

# Check management logs on node 1
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "docker logs netbird-management --tail 50 | grep -i database"
```

**Expected**: API works, node 1 logs show DB connection errors

#### Step 5: Restore PgBouncer

```bash
# Start PgBouncer
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "cd /opt/netbird && docker-compose start pgbouncer"

# Wait for connections to establish
sleep 10
```

#### Step 6: Verify Full Recovery

```bash
# Check PgBouncer pools
ansible <mgmt-node-1> -i inventory/terraform_inventory.yaml \
  -m shell -a "docker exec pgbouncer psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS;'"

# Check management health
curl -s https://your-domain.com:8404/stats | grep <mgmt-node-1>
```

**Expected**: Node 1 returns to UP status

</details>

---

## Verification

### Post-Test Verification Checklist

<details open>
<summary>Expand/Collapse Verification</summary>

After completing all tests:

- [ ] **All Services Restored**
  - All containers running
  - All nodes show UP in HAProxy
  - VIP on correct node

- [ ] **No Errors in Logs**
  - Check management logs
  - Check HAProxy logs
  - Check PgBouncer logs
  - Check DNS/Load Balancer logs

- [ ] **Client Connectivity**
  - Test clients connected
  - Peers can communicate
  - No connection drops reported

- [ ] **Monitoring Alerts**
  - Review any alerts triggered
  - Verify alerts cleared
  - Check alert timing was appropriate

- [ ] **Performance Baseline**
  - Response times normal
  - Resource usage normal
  - No degradation observed

**Verification Commands:**
```bash
# Check all services
ansible all -i inventory/terraform_inventory.yaml \
  -m shell -a "docker ps | grep netbird"

# Check HAProxy status
curl -s https://your-domain.com:8404/stats | grep -E 'backend|UP|DOWN'

# Check for errors
ansible all -i inventory/terraform_inventory.yaml \
  -m shell -a "docker logs netbird-management --since 1h | grep -i error"

# Test API
curl -f https://your-domain.com/health

# Test client
netbird status
```

</details>

---

## Best Practices

### 1. Split-Brain Prevention

<details>
<summary>Expand/Collapse Split-Brain Prevention</summary>

Use DNS round-robin or an external load balancer to distribute traffic across multiple HAProxy nodes. This prevents single points of failure without requiring complex VRRP configurations.

**Configuration Example:**
```bash
# DNS Round Robin (multiple A records)
vpn.example.com.  300  IN  A  203.0.113.10
vpn.example.com.  300  IN  A  203.0.113.11
vpn.example.com.  300  IN  A  203.0.113.12
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 101
    
    track_script {
        chk_haproxy
    }
    
    virtual_ipaddress {
        203.0.113.100/24
    }
}
```

</details>

### 2. Connection Draining

<details>
<summary>Expand/Collapse Connection Draining</summary>

When performing planned maintenance, use HAProxy maintenance mode to drain connections gracefully:

```bash
# Put server in maintenance mode
echo "disable server netbird_backend/mgmt-1" | sudo socat stdio /var/run/haproxy.sock

# Wait for connections to drain
watch 'echo "show stat" | sudo socat stdio /var/run/haproxy.sock | grep mgmt-1'

# Perform maintenance
# ...

# Bring server back online
echo "enable server netbird_backend/mgmt-1" | sudo socat stdio /var/run/haproxy.sock
```

</details>

### 3. Automated Alerting

<details>
<summary>Expand/Collapse Alerting Configuration</summary>

Configure monitoring alerts for HA health:

**Prometheus Alert Rules:**
```yaml
groups:
  - name: netbird_ha
    rules:
      - alert: HAProxyBackendDown
        expr: haproxy_backend_active_servers{backend="netbird_backend"} < 3
        for: 1m
        annotations:
          summary: "HA cluster running at reduced capacity"
          
      - alert: HAProxyNodeUnreachable
        expr: up{job="haproxy"} == 0
        for: 30s
        annotations:
          summary: "HAProxy node is unreachable"
```

</details>

### 4. Regular Testing Schedule

- **Quarterly**: Full failover test suite
- **Monthly**: Single component failover test
- **After Changes**: Targeted failover test for changed components
- **Incident Response**: Test after any HA-related incident

### 5. Documentation

Document each test:
- Date and time
- Components tested
- Results and timing
- Issues encountered
- Lessons learned

---

## Related Documentation

- [Deployment Guide](./deployment.md)
- [Database Management](./database-management.md)
- [Operations Book](../../operations-book/ansible-stack/operations-book.md)
- [Monitoring & Alerting](../../operations-book/monitoring-alerting.md)

