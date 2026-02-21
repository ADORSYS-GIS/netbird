# Additional Issues Found - Extended Audit
## NetBird HA Deployment - Hidden Vulnerabilities & Failure Points

**Date**: 2026-02-21  
**Scope**: Deep analysis beyond initial audit  
**Severity**: 13 additional issues (1 CRITICAL, 4 HIGH, 5 MEDIUM, 3 LOW)

---

## CRITICAL ISSUE

### 1. 🔴 ALL CONTAINERS USING `recreate: true` - Unnecessary Restarts

**Impact**: HIGH - Causes service interruption on EVERY `terraform apply`

**Files Affected**:
- `netbird-management/tasks/main.yml` (line 32)
- `netbird-signal/tasks/main.yml` (line 23)
- `netbird-dashboard/tasks/main.yml` (line 23)
- `netbird-relay/tasks/main.yml` (line 13)
- `netbird-coturn/tasks/main.yml` (line 33)
- `haproxy/tasks/main.yml` (line 35)
- `reverse-proxy/tasks/main.yml` (line 32)

**Current Behavior**:
```yaml
recreate: true  # ← PROBLEM: Always recreates, even if config unchanged
```

**Problem**:
- Container is destroyed and recreated EVERY apply
- Causes temporary service interruption
- Breaks idempotency (unnecessary changes)
- NOT idempotent-ideal for HA environment

**Solution**:
```yaml
recreate: false  # Only recreate if config changes
```

**BUT** - Need to validate:
- If image changes, does it auto-pull and recreate?
- If config changes (via notify handler), does it recreate?

**Testing**:
```bash
# Run apply twice - second time should show no changes
terraform apply
terraform apply  # Should be no-op
```

---

## HIGH PRIORITY ISSUES

### 2. 🟠 NO CONTAINER RESOURCE LIMITS - OOM/CPU Exhaustion Risk

**Files Affected**: ALL docker_container tasks

**Current State**:
```yaml
community.docker.docker_container:
  name: netbird-management
  # NO memory limits
  # NO cpu limits
  # NO memory reservation
```

**Risk**:
- Management container could consume all host RAM
- Signal/relay containers could consume all CPU
- No protection against resource exhaustion
- HA environment NEEDS limits for proper failover

**Recommended Limits**:
```yaml
# Management node (management + signal + dashboard on same host)
netbird-management:
  memory: "2g"           # 2GB max
  memory_swap: "2g"      # No swap
  
netbird-signal:
  memory: "1g"           # 1GB max
  
netbird-dashboard:
  memory: "512m"         # 512MB max
  
netbird-relay:
  memory: "1g"           # 1GB max
  
pgbouncer:
  memory: "512m"         # 512MB max
  
haproxy:
  memory: "512m"         # 512MB max
  
coturn:
  memory: "1g"           # 1GB max (media streaming)
```

**How to Add** (in all docker_container tasks):
```yaml
- name: Manage NetBird Management container
  community.docker.docker_container:
    ...
    memory: "2g"
    memory_reservation: "1g"  # Soft limit
    memory_swap: "2g"
    oom_kill_disable: false   # Kill container if OOM
```

**Note**: Exact values depend on deployment size. Above is for 3 management nodes.

---

### 3. 🟠 NO CONTAINER HEALTH CHECKS - Silent Failures

**Services WITHOUT health checks**:
- ✗ netbird-management (port 9000 has health endpoint!)
- ✗ netbird-signal (port 80 has health endpoint!)
- ✗ netbird-dashboard (port 80 has health endpoint!)
- ✗ netbird-relay (port 33080)
- ✓ pgbouncer (has health check)
- ✗ haproxy (port 8404 has stats!)
- ✗ reverse-proxy/caddy (port 80 has health endpoint!)

**Risk**:
- Docker won't detect if service internally crashes
- HAProxy continues routing to dead backend
- Clients get 502/503 errors
- No automatic restart on crash

**Solution**:
```yaml
# Management
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
  interval: "10s"
  timeout: "5s"
  retries: 3
  start_period: "30s"

# Signal
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:80/status"]
  interval: "10s"
  timeout: "5s"
  retries: 3
  start_period: "30s"

# Dashboard
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:80/"]
  interval: "30s"
  timeout: "5s"
  retries: 3
  start_period: "60s"

# HAProxy
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8404/stats"]
  interval: "10s"
  timeout: "5s"
  retries: 3
  start_period: "15s"
```

---

### 4. 🟠 HAProxy Using "latest" Tag - Unpredictable Behavior

**File**: `haproxy/tasks/main.yml` (line 31)

**Current**:
```yaml
image: "ghcr.io/flobernd/haproxy-acme-http01:latest"  # ← PROBLEM
```

**Risk**:
- Custom HAProxy image updated without control
- Breaking changes possible
- Reproducibility lost
- HA deployments need predictable versions

**Solution**:
```yaml
image: "ghcr.io/flobernd/haproxy-acme-http01:v1.6.0"  # Pin version
```

**How to find version**:
```bash
docker pull ghcr.io/flobernd/haproxy-acme-http01:latest
docker inspect ghcr.io/flobernd/haproxy-acme-http01:latest | grep -i version
```

---

### 5. 🟠 Caddy Using "latest" by Default - Version Unpredictability

**File**: `reverse-proxy/tasks/main.yml` (line 28)

**Current**:
```yaml
image: "caddy:{{ caddy_version | default('latest') }}"  # ← default latest
```

**Issue**:
- If `caddy_version` undefined, falls back to "latest"
- Inconsistent between deployments

**Solution**:
Ensure terraform.tfvars always sets explicit version:
```hcl
caddy_version = "2.8.0"  # Never "latest"
```

---

### 6. 🟠 COTURN Port Range Not Working with UFW - Firewall Issues

**File**: `netbird-coturn/tasks/main.yml` (line 54)

**Current**:
```yaml
- { port: '{{ coturn_min_port }}:{{ coturn_max_port }}', proto: 'udp', comment: 'Coturn Relay Range' }
# Expands to: port: '49152:65535'
```

**Problem**:
- UFW doesn't handle port ranges the same way
- May leave old rules behind on updates
- Port range syntax differs between UFW versions
- TURN relay won't work if ports blocked

**Solution**:
Instead of range, use UFW rule directly:
```yaml
- name: Manage Coturn ports (UFW)
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
    proto: "{{ item.proto }}"
    comment: "{{ item.comment }}"
  loop:
    - { port: '3478', proto: 'udp', comment: 'Coturn STUN/TURN UDP' }
    - { port: '3478', proto: 'tcp', comment: 'Coturn STUN/TURN TCP' }
  
- name: Allow TURN relay port range (iptables fallback)
  ansible.builtin.iptables:
    chain: INPUT
    protocol: udp
    match: "dport"
    dport: "{{ coturn_min_port }}:{{ coturn_max_port }}"
    jump: ACCEPT
    state: present
  register: iptables_result
  ignore_errors: true  # If iptables not available, will be silently skipped
```

OR simpler - just document the requirement:
```yaml
- name: Ensure TURN relay port range is open
  ansible.builtin.debug:
    msg: "IMPORTANT: Ensure firewall allows UDP {{ coturn_min_port }}:{{ coturn_max_port }} - required for TURN relay"
```

---

## MEDIUM PRIORITY ISSUES

### 7. 🟡 NO SERVICE DEPENDENCIES - Undefined Start Order

**Issue**: Containers start in parallel, no guaranteed order

**Example**:
```
Scenario: HAProxy starts before management nodes
Result: HAProxy health check fails, routes to dead backend
```

**Current**: All roles run in parallel:
```yaml
- name: Deploy PgBouncer... (if enabled)
  ...
- name: Deploy NetBird Management Servers
  ...
- name: Deploy NetBird Relay Servers
  ...
- name: Deploy Reverse Proxy & Load Balancer
  ...
```

**Proper Order Should Be**:
1. PgBouncer (database pooling)
2. Management nodes (core service)
3. Signal servers (communication)
4. Dashboard (UI)
5. Relay (optional)
6. HAProxy (last, needs all backends ready)

**Solution**: Add explicit waits

```yaml
- name: Deploy PgBouncer Connection Pooler
  ...

- name: Wait for PgBouncer to be ready
  ansible.builtin.wait_for:
    host: localhost
    port: 6432
    timeout: 30
    
- name: Deploy NetBird Management Servers
  ...
  
- name: Wait for Management service to be ready
  ansible.builtin.wait_for:
    port: 8081
    timeout: 60
  delegate_to: "{{ item }}"
  loop: "{{ groups['management'] }}"
```

---

### 8. 🟡 NO VOLUME CLEANUP (except Caddy) - Disk Space Leak

**Issue**: Old volumes accumulate on destroy

**Files Affected**:
- ✗ netbird-management (no cleanup)
- ✗ netbird-signal (no cleanup)
- ✗ netbird-dashboard (no cleanup)
- ✗ netbird-relay (no cleanup)
- ✗ netbird-coturn (no cleanup)
- ✗ pgbouncer (no cleanup)
- ✗ haproxy (no cleanup)
- ✓ reverse-proxy/caddy (HAS cleanup)

**Problem**:
```bash
# After destroy + redeploy many times:
docker volume ls  # Hundreds of orphaned volumes
du -sh /var/lib/docker/volumes/  # GBs of unused data
```

**Solution**: Add cleanup tasks for each role

```yaml
# At end of each role's main.yml
- name: Remove {{ service_name }} Docker volumes
  community.docker.docker_volume:
    name: "{{ item }}"
    state: absent
  loop:
    - "netbird_management_data"
    - "netbird_management_config"
  when: netbird_state | default('present') == 'absent'
```

---

### 9. 🟡 NO CONTAINER USER/PERMISSION MANAGEMENT - Security Gap

**Issue**: All containers run as root (or default user)

**Current**:
```yaml
community.docker.docker_container:
  name: netbird-management
  # NO user specified - defaults to root or Dockerfile user
```

**Risk**:
- Container escape = full host compromise
- No isolation between containers

**Better Approach**:
```yaml
# For management, signal, dashboard, relay:
user: "1000:1000"  # Run as non-root UID:GID

# For HAProxy:
user: "80:80"      # HAProxy standard user
```

**Note**: Images would need to support this. For now, document the requirement.

---

### 10. 🟡 NO RESTART DELAY - Potential Flapping

**Current**:
```yaml
restart_policy: unless-stopped
# NO restart_max_retries
# NO restart_wait_timeout
```

**Risk**:
- If service crashes in loop, constant restart attempts
- CPU/disk thrashing
- Looks like normal operation

**Solution**:
```yaml
restart_policy: on-failure
restart_max_retries: 5
restart_wait_timeout: 5  # 5 second wait between retries
```

---

### 11. 🟡 LOG ROTATION - Disk Space Issues

**Current**:
```yaml
log_driver: "json-file"
log_options:
  max-size: "500m"
  max-file: "2"
```

**Calculation**:
- 500m × 2 files = 1GB per container
- 7 containers × 1GB = 7GB logs
- Over time with multiple deployments: 20-50GB+

**Recommendation**:
```yaml
log_options:
  max-size: "100m"    # Smaller per file
  max-file: "5"       # Keep 5 rotated files = 500MB per container
  # Total: ~3.5GB for all containers
  labels: "netbird"   # For easier identification
```

OR use centralized logging (Loki, ELK) for production.

---

## LOW PRIORITY ISSUES

### 12. 🟢 COTURN HOST NETWORK MODE - Necessary but Needs Documentation

**File**: `netbird-coturn/tasks/main.yml` (line 34)

**Current**:
```yaml
network_mode: host  # Bypasses Docker's network isolation
```

**Why Necessary**:
- STUN/TURN requires raw UDP access
- Docker bridge mode adds latency
- Host mode is only option for performance

**Recommendation**: Add comment
```yaml
network_mode: host  # REQUIRED for STUN/TURN performance - necessary security tradeoff
```

---

### 13. 🟢 NO KEYCLOAK CONNECTIVITY TEST - Silent Failure

**Issue**: If Keycloak is down during deploy, playbook doesn't fail early

**Suggestion**:
```yaml
- name: Verify Keycloak connectivity
  ansible.builtin.uri:
    url: "{{ keycloak_url }}/.well-known/openid-configuration"
    validate_certs: true
    timeout: 10
  register: keycloak_check
  failed_when: keycloak_check.status != 200
  
- name: Fail if Keycloak unreachable
  ansible.builtin.fail:
    msg: "Keycloak unreachable at {{ keycloak_url }}"
  when: keycloak_check.status != 200
```

---

### 14. 🟢 NO DATABASE CONNECTIVITY TEST - Delayed Failure

**Issue**: Database connection errors discovered during container startup, not during planning

**Suggestion**:
```yaml
- name: Test PostgreSQL connectivity
  ansible.builtin.postgresql_query:
    db: "{{ database_name }}"
    query: "SELECT version();"
    login_host: "{{ database_endpoint }}"
    login_user: "{{ database_username }}"
    login_password: "{{ database_password }}"
    ssl_mode: "{{ database_sslmode }}"
  register: pg_test
  failed_when: pg_test.failed
```

---

## Summary: All Additional Issues

| # | Issue | Severity | Type | Status |
|----|-------|----------|------|--------|
| 1 | All containers use `recreate: true` | CRITICAL | Idempotency | Identified |
| 2 | No resource limits | HIGH | Reliability | Identified |
| 3 | Missing health checks | HIGH | Reliability | Identified |
| 4 | HAProxy latest tag | HIGH | Predictability | Identified |
| 5 | Caddy latest default | HIGH | Predictability | Identified |
| 6 | UFW port range issue | HIGH | Functionality | Identified |
| 7 | No service dependencies | MEDIUM | Reliability | Identified |
| 8 | No volume cleanup | MEDIUM | Operations | Identified |
| 9 | Containers run as root | MEDIUM | Security | Identified |
| 10 | No restart delays | MEDIUM | Reliability | Identified |
| 11 | Log rotation needs review | MEDIUM | Operations | Identified |
| 12 | Coturn host mode | LOW | Documentation | Identified |
| 13 | No Keycloak test | LOW | Debugging | Identified |
| 14 | No DB connectivity test | LOW | Debugging | Identified |

---

## Recommended Fix Priority

### Phase 1: MUST DO (Blocking HA)
1. Fix `recreate: true` → `recreate: false`
2. Add health checks to all services
3. Add resource limits
4. Pin HAProxy version (not latest)

### Phase 2: SHOULD DO (Before Production)
5. Add container health checks
6. Fix UFW port range handling
7. Add service dependencies & wait conditions
8. Add volume cleanup on destroy

### Phase 3: NICE TO HAVE (Long-term)
9. Add restart delay logic
10. Review log rotation
11. Add security context/user management
12. Add pre-deployment connectivity tests

---

## Testing the Additional Issues

```bash
# Test 1: Check for unnecessary container recreation
terraform apply
terraform apply
# Second apply should show NO container changes

# Test 2: Verify memory limits
docker inspect netbird-management | grep -i memory

# Test 3: Check health checks
docker inspect netbird-management | grep -i health

# Test 4: Verify version pinning
docker images | grep -E "latest|netbird|caddy|haproxy"
# Should NOT show "latest" tags

# Test 5: Check volumes after destroy
docker volume ls
# Should be empty or minimal
```

---

## Files to Update

Based on issues found, these files need updates:
1. All `*/tasks/main.yml` in roles
2. `templates/inventory.yaml.tpl` (add validation)
3. `group_vars/all.yml` (add limits, health check configs)
4. `playbooks/site.yml` (add dependencies/waits)
5. Documentation (new security section)
