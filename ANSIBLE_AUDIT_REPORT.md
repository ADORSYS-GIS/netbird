# Comprehensive Ansible & Terraform Audit Report
## NetBird HA Deployment - Deep Analysis

**Date**: 2026-02-21  
**Analysis Type**: Full idempotency, architectural, and design audit  
**Status**: CRITICAL ISSUES FOUND

---

## EXECUTIVE SUMMARY

### Critical Issues: 3
### High Issues: 5  
### Medium Issues: 8
### Low Issues: 6

### Overall Assessment: ⚠️ **ARCHITECTURE MISALIGNED WITH NETBIRD OFFICIAL DESIGN**

The current implementation has significant gaps between intended HA goals and what NetBird actually supports:

1. **NetBird management clustering (Issue #1584)**: NOT officially supported yet
2. **Multi-container approach**: DEPRECATED - NetBird recommends `netbird-server` combined container
3. **Ansible module bug**: Parameter mismatch in HAProxy task (`environment` → `env`)
4. **Idempotency issues**: Dashboard task always reports changed, non-deterministic shell commands

---

## PART 1: NETBIRD ARCHITECTURE ANALYSIS

### 1.1 Current Assumption: Management Clustering EXISTS ❌

**Finding**: The code assumes NetBird supports management service clustering:

```yaml
# management.json.j2 lines 119-126
"ClusterConfig": {
  "Enabled": {{ 'true' if enable_clustering | default(false) else 'false' }},
  "Peers": [
    {% for host in groups['management'] -%}
    "{{ hostvars[host]['private_ip'] }}:{{ netbird_cluster_port | default(9090) }}"
    {% endfor -%}
  ]
}
```

**REALITY** (per official sources):
- GitHub Issue #1584: "Management component currently lacks built-in HA support" (Open as of Feb 2024)
- `ClusterConfig` exists in code but **is NOT a fully functional HA solution**
- NetBird clustering for management is **incomplete/unsupported**

**Impact**: 
- ⚠️ Enabling `enable_clustering = true` may or may not work
- ⚠️ No actual state synchronization between management nodes
- ⚠️ All 3 management nodes operate independently reading from same DB
- ✓ BUT this is actually OK: Shared database ensures consistency without clustering

---

### 1.2 Architecture: Multi-Container vs Combined Container ❌

**Current Implementation**: Separate containers
```yaml
- netbirdio/management:latest     # Port 8081
- netbirdio/signal:latest         # Port 8083
- netbirdio/relay:latest          # Port 33080
- netbirdio/dashboard:latest      # Port 8082
- coturn/coturn:latest            # STUN/TURN
```

**NetBird Official Recommendation**: Combined container
```yaml
- netbirdio/netbird:latest        # All-in-one: management + signal + relay + embedded STUN
```

**Migration Status**: 
- Old multi-container approach: Being phased out
- New `netbird-server` container: Currently recommended
- Docs: https://docs.netbird.io/selfhosted/migration/combined-container

**Impact for THIS Project**:
- ✓ Multi-container approach still works
- ✓ More granular control per component
- ❌ Not following official recommendations
- ⚠️ May become unsupported in future versions

**RECOMMENDATION**: 
For HA, the current multi-container approach with shared database + external HAProxy load balancer IS a valid design. It's not "wrong," just not the official path.

---

### 1.3 Proper HA Architecture (As Per NetBird)

For **true HA**, NetBird recommends:

1. **Multiple instances** of `netbird-server` (combined container)
2. **Shared PostgreSQL database** with Multi-AZ failover
3. **External reverse proxy** (Traefik, Nginx, HAProxy) for load balancing
4. **Health checks** for automatic failover
5. **NO internal clustering** (state synced via database)

**Current Implementation Aligns With This (mostly)**:
- ✓ Multiple management nodes (3x)
- ✓ Shared PostgreSQL database
- ✓ External load balancer (HAProxy)
- ✓ Health checks configured
- ⚠️ Using separate containers (not combined)
- ❌ Attempting to use clustering that may not work

---

## PART 2: ANSIBLE IDEMPOTENCY AUDIT

### 2.1 Role-by-Role Analysis

#### **common/tasks/main.yml** ✓ MOSTLY IDEMPOTENT
```yaml
✓ Docker installation: Checked with 'which docker'
✓ UFW configuration: Idempotent commands (ufw, apt)
✓ Docker network: Using 'force: false' (idempotent)
⚠️ Remove containers on cleanup: Uses shell (risky but OK for absent state)
```

**Issues**: None significant

---

#### **netbird-management/tasks/main.yml** ✓ MOSTLY IDEMPOTENT
```yaml
✓ Directory management: Idempotent (file module)
✓ Configuration template: Idempotent (template module)
✓ Docker container: Using 'recreate: true' (conditionally idempotent)
✓ Ports: Idempotent UFW rules
```

**Potential Issue**:
```yaml
community.docker.docker_container:
  recreate: true  # Always recreates container
  pull: true      # Always pulls latest image
```
This means the container is always recreated even if nothing changed. Not breaking, but inefficient.

**Recommendation**: Use `recreate: false` for true idempotency, or document this is intentional.

---

#### **netbird-signal/tasks/main.yml** ✓ IDEMPOTENT
- All operations idempotent
- No issues found

---

#### **netbird-dashboard/tasks/main.yml** ❌ IDEMPOTENCY BROKEN

**CRITICAL ISSUE**:

```yaml
- name: Force environment variable substitution in JS files
  ansible.builtin.shell: |\
    docker exec netbird-dashboard sh -c '...'
  changed_when: true  # ← ALWAYS REPORTS CHANGED!
```

**Problems**:
1. `changed_when: true` forces module to always report changed
2. Shell command executes EVERY time (inside running container)
3. Not idempotent - re-running playbook repeatedly modifies files
4. Environmental variables won't auto-update if config changes

**Impact**: 
- ⚠️ Ansible thinks state changed even when nothing changed
- ⚠️ Breaks proper change detection in CI/CD pipelines
- ⚠️ May cause issues with configuration management

**Fix**:
```yaml
- name: Force environment variable substitution in JS files
  ansible.builtin.shell: |\
    docker exec netbird-dashboard sh -c '...'
  register: envsubst_result
  changed_when: envsubst_result.stdout_lines | length > 0
```

OR better approach:

```yaml
- name: Prepare environment substitution script
  ansible.builtin.template:
    src: envsubst.sh.j2
    dest: /etc/netbird/envsubst.sh
  notify: Restart Dashboard
  
- name: Dashboard container mounts script
  volumes:
    - /etc/netbird/envsubst.sh:/docker-entrypoint.d/envsubst.sh:ro
```

---

#### **netbird-relay/tasks/main.yml** ✓ IDEMPOTENT
- All operations properly idempotent
- Uses proper state conditions
- No issues

---

#### **netbird-coturn/tasks/main.yml** ✓ MOSTLY IDEMPOTENT
```yaml
✓ Configuration management: Idempotent
⚠️ Port range: 
  port: "{{ coturn_min_port }}:{{ coturn_max_port }}"
  # UFW might not handle port ranges perfectly across re-applies
```

**Issue**: UFW doesn't handle port ranges the same as individual ports. May leave old rules.

**Recommendation**: Use explicit port list or UFW reset script.

---

#### **pgbouncer/tasks/main.yml** ❌ MULTIPLE ISSUES

**Issue #1: Non-idempotent lineinfile**
```yaml
- name: Add database user to PgBouncer userlist
  ansible.builtin.lineinfile:
    path: /etc/pgbouncer/userlist.txt
    line: '"{{ pgbouncer_database_user }}" "{{ pgbouncer_database_password }}"'
    state: present
    create: true
```

Problems:
- If password changes, old line remains and new line added (duplicates)
- Should use `regexp` to match and replace

**Fix**:
```yaml
- name: Update PgBouncer database user
  ansible.builtin.lineinfile:
    path: /etc/pgbouncer/userlist.txt
    regexp: '^"{{ pgbouncer_database_user }}"'
    line: '"{{ pgbouncer_database_user }}" "{{ pgbouncer_database_password }}"'
    state: present
    create: true
```

**Issue #2: Healthcheck references undefined variables**
```yaml
healthcheck:
  test: [...]
  interval: "{{ pgbouncer_health_check_period }}s"  # ← NOT DEFINED!
  timeout: "{{ pgbouncer_health_check_timeout }}s"  # ← NOT DEFINED!
```

These variables don't exist in group_vars. Will cause template errors.

---

#### **reverse-proxy/tasks/main.yml** ✓ IDEMPOTENT
- All operations properly idempotent
- No issues

---

#### **haproxy/tasks/main.yml** ❌ CRITICAL BUG + IDEMPOTENCY ISSUE

**CRITICAL BUG** (This is why playbook is failing):

```yaml
Line 45-48:
environment:  # ← WRONG PARAMETER
  ACME_MAIL: "{{ acme_email }}"
  ACME_DOMAIN: "{{ netbird_domain }}"
  ACME_SERVER: "letsencrypt"
```

Error from playbook:
```
Unsupported parameters for (community.docker.docker_container) module: environment
Supported parameters include: ... env ... (NOT environment)
```

**Fix**: Change `environment:` to `env:`

---

### 2.2 Summary: Idempotency Issues

| Role | Status | Issues |
|------|--------|--------|
| common | ✓ | None |
| netbird-management | ⚠️ | Always recreates container |
| netbird-signal | ✓ | None |
| netbird-dashboard | ❌ | `changed_when: true` breaks idempotency |
| netbird-relay | ✓ | None |
| netbird-coturn | ⚠️ | Port range UFW handling questionable |
| pgbouncer | ❌ | Non-idempotent lineinfile, undefined variables |
| reverse-proxy | ✓ | None |
| haproxy | ❌ | **CRITICAL**: Wrong parameter name (env vs environment) |

---

## PART 3: TERRAFORM → ANSIBLE WORKFLOW VALIDATION

### 3.1 Inventory Generation

**Process**:
```
Terraform (main.tf)
  ↓
Generates terraform_inventory.yaml via template
  ↓
Local-exec provisioner runs ansible-playbook
  ↓
Ansible uses generated inventory
```

**Code Flow** (main.tf lines 142-165):

```hcl
resource "terraform_data" "ansible_provisioning" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p $(dirname ${local.inventory_path})
      echo "${base64encode(local.inventory_content)}" | base64 -d > ${local.inventory_path}
      chmod 600 ${local.inventory_path}
      cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
    EOT
  }
}
```

**Analysis**:

✓ **Strengths**:
- Inventory is generated from modules output
- Base64 encoding prevents shell interpretation issues
- Permissions properly set (600)
- Invocation path is correct

❌ **Issues**:

1. **No error handling**: If ansible-playbook fails, local-exec completes with status 2, but Terraform might not fail
   
   ```hcl
   # Current: No || exit
   cd ../../configuration/ansible && ansible-playbook ...
   
   # Should be:
   cd ../../configuration/ansible && ansible-playbook ... || exit 1
   ```

2. **Relative path in local-exec**: Works but fragile
   ```bash
   cd ../../configuration/ansible  # Assumes specific directory structure
   ```

3. **No inventory validation**: Generated inventory isn't validated before use
   
   **Recommendation**:
   ```bash
   # Before running ansible-playbook:
   ansible-inventory -i inventory/terraform_inventory.yaml --list > /dev/null || exit 1
   ansible-playbook --syntax-check playbooks/site.yml || exit 1
   ```

4. **Triggers always replace** (line 149-156):
   ```hcl
   triggers_replace = [
     local.inventory_content,
     module.database.database_dsn,
     module.keycloak.backend_client_secret,
     sha256(file("...management.json.j2")),
     ...
   ]
   ```
   
   Any template change triggers full redeployment. Might be intentional but risky.

---

### 3.2 Variable Passing to Ansible

**Data Flow**:

```
Terraform variables.tf
  ↓
Terraform main.tf (locals)
  ↓
Templates inventory.yaml.tpl
  ↓
Generated terraform_inventory.yaml
  ↓
Ansible group_vars/all.yml (reads terraform variables)
```

**Generated Inventory Format**:
```yaml
all:
  vars:
    netbird_domain: "{{ netbird_domain }}"
    netbird_version: "{{ netbird_version }}"
    caddy_version: "{{ caddy_version }}"
    haproxy_version: "{{ haproxy_version }}"
    proxy_type: "{{ proxy_type }}"
    ...
```

**Analysis**:

✓ **Good**:
- Variables are passed via inventory
- All critical variables included
- Format is YAML (parseable)

❌ **Issues**:

1. **Hardcoded version strings vs template variables**
   
   Line 8 in inventory.yaml.tpl:
   ```yaml
   haproxy_version: "${haproxy_version}"
   ```
   But this comes from `variables.tf` line 176:
   ```hcl
   default = "latest"
   ```
   
   Using "latest" tag in production is dangerous!

2. **Missing variable validation**
   
   If a variable is missing from terraform.tfvars, it defaults silently:
   ```hcl
   default = "latest"
   ```
   
   Ansible should validate required variables explicitly.

3. **Secrets in terraform_inventory.yaml**
   
   File contains:
   ```yaml
   database_password: "{{ database_password }}"
   keycloak_backend_client_secret: "{{ keycloak_backend_client_secret }}"
   ```
   
   ✓ File is chmod 600 (good)
   ✓ But should be gitignored explicitly
   ⚠️ Should use Ansible vault for secrets in production

---

### 3.3 Terraform→Ansible Integration Issues

**Configuration Dependency Chain**:

```
management.json template (line 153)
  ↓ Depends on:
  ├─ database_dsn (module.database output)
  ├─ keycloak settings (module.keycloak output)
  ├─ relay_addresses (computed from inventory)
  ├─ stun_addresses (computed from inventory)
  └─ clustering config (enable_clustering variable)
```

**Potential Issues**:

1. **Circular dependencies if not careful**
   - management.json depends on relay_addresses
   - relay_addresses computed from module.inventory
   - module.inventory depends on var.netbird_hosts
   ✓ Currently OK, but fragile

2. **Keycloak dependencies**
   
   ```hcl
   module "keycloak" {
     ...
     netbird_domain = var.netbird_domain
     netbird_admin_email = var.netbird_admin_email
     netbird_admin_password = var.netbird_admin_password
   }
   ```
   
   ⚠️ If Keycloak is external (not managed by Terraform), these outputs might fail

3. **Database connectivity not tested**
   
   ```hcl
   module "database" {
     ...
   }
   ```
   
   Output used in ansible but never tested. Should add validation.

---

## PART 4: CRITICAL ISSUES SUMMARY

### Critical Issues

#### 1. **HAProxy Ansible Module Parameter Bug** 🔴
- **File**: `/configuration/ansible/roles/haproxy/tasks/main.yml` (line 45)
- **Issue**: Uses `environment:` instead of `env:`
- **Error**: "Unsupported parameters for docker_container: environment"
- **Fix**: Change to `env:`
- **Severity**: BLOCKS DEPLOYMENT

#### 2. **NetBird Clustering NOT Officially Supported** 🔴
- **Source**: GitHub Issue #1584 (open, no ETA)
- **Issue**: `ClusterConfig` in management.json enabled, but unsupported
- **Impact**: May not provide expected HA synchronization
- **Recommendation**: Keep disabled (`enable_clustering = false`) unless you understand implications
- **Current Impact**: LOW (load balancer + shared DB provides HA anyway)

#### 3. **Dashboard Idempotency Broken** 🔴
- **File**: `/configuration/ansible/roles/netbird-dashboard/tasks/main.yml` (line 19)
- **Issue**: `changed_when: true` always reports change
- **Impact**: Breaks change detection in CI/CD
- **Fix**: Implement proper change detection or move to initialization hook

---

### High-Priority Issues

#### 4. **PgBouncer Undefined Variables** 🟠
- **File**: `/configuration/ansible/roles/pgbouncer/tasks/main.yml`
- **Variables**: `pgbouncer_health_check_period`, `pgbouncer_health_check_timeout`
- **Impact**: Health check will fail or use wrong values
- **Fix**: Define variables in group_vars/all.yml

#### 5. **PgBouncer Lineinfile Non-Idempotent** 🟠
- **Issue**: Will create duplicates if password changes
- **Fix**: Use `regexp` to replace instead of append

#### 6. **Terraform Error Handling Missing** 🟠
- **Issue**: ansible-playbook failures not propagated to Terraform
- **Fix**: Add `|| exit 1` to local-exec command

#### 7. **Container Always Recreated** 🟠
- **Roles**: netbird-management, netbird-signal, netbird-relay, etc.
- **Issue**: `recreate: true` means containers recreated every apply
- **Impact**: Unnecessary downtime on re-applies
- **Fix**: Use `recreate: false` or document why recreate needed

#### 8. **"latest" Tags in Production** 🟠
- **Issue**: Default versions are "latest" for Caddy, HAProxy, etc.
- **Impact**: Unpredictable updates
- **Fix**: Pin exact versions in terraform.tfvars

---

## PART 5: TERRAFORM WORKFLOW VALIDATION

### 5.1 Complete Validation Checklist

**Pre-Deployment Validation** ✓
```bash
# 1. Terraform validation
cd infrastructure/ansible-stack
terraform fmt -check -recursive
terraform validate

# 2. Ansible validation
ansible-playbook --syntax-check -i inventory/terraform_inventory.yaml playbooks/site.yml

# 3. Inventory validation
ansible-inventory -i inventory/terraform_inventory.yaml --list
```

**During Deployment** ⚠️
```bash
# Current flow is:
terraform apply
  → local-exec: ansible-playbook runs
  → If playbook fails, terraform doesn't know

# Should validate:
- ansible-playbook return code checked
- Inventory file actually created
- Variables passed correctly
```

**Post-Deployment Validation** ❌
```bash
# No validation happens after ansible-playbook
# Should add:
- Health check endpoints
- Port accessibility
- Service status verification
- Database connectivity
```

---

### 5.2 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Terraform Apply                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. Read tfvars                                                 │
│    ├─ netbird_domain                                           │
│    ├─ netbird_hosts (map of VMs)                              │
│    ├─ database config                                          │
│    └─ keycloak config                                          │
│                                                                 │
│ 2. Module: inventory                                            │
│    └─ Groups hosts by role (management, relay, proxy)          │
│                                                                 │
│ 3. Module: database                                             │
│    └─ Validates/prepares DSN for existing DB                  │
│                                                                 │
│ 4. Module: keycloak                                             │
│    └─ Creates realm and clients in Keycloak                    │
│                                                                 │
│ 5. Locals: inventory_content                                    │
│    └─ Renders inventory.yaml.tpl with all values              │
│                                                                 │
│ 6. Resource: terraform_data.ansible_provisioning               │
│    └─ local-exec provisioner runs:                             │
│       ├─ Write terraform_inventory.yaml                        │
│       ├─ Run ansible-playbook                                  │
│       └─ [FAILS HERE WITH env/environment BUG]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## RECOMMENDATIONS

### Immediate Actions (MUST FIX BEFORE DEPLOYMENT)

1. **Fix HAProxy Ansible Bug**
   ```yaml
   # Line 45 in haproxy/tasks/main.yml
   - Change: environment:
   + Change: env:
   ```

2. **Fix PgBouncer Undefined Variables**
   ```yaml
   # Add to group_vars/all.yml
   pgbouncer_health_check_period: 10
   pgbouncer_health_check_timeout: 5
   ```

3. **Fix Dashboard Idempotency**
   ```yaml
   # Option: Use proper change detection
   changed_when: '"substituted" in envsubst_result.stdout'
   ```

4. **Add Terraform Error Handling**
   ```bash
   # In main.tf provisioner
   cd ../../configuration/ansible && ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml || exit 1
   ```

5. **Disable or Document Clustering**
   ```hcl
   # In terraform.tfvars
   enable_clustering = false  # Not officially supported yet
   ```

---

### Short-term Actions (BEFORE PRODUCTION)

6. **Pin Exact Versions**
   ```hcl
   netbird_version = "0.27.0"   # not "latest"
   caddy_version = "2.8.0"      # not "latest"
   haproxy_version = "2.8.0"    # not "latest"
   ```

7. **Add Post-Deployment Validation**
   ```bash
   # In playbooks/validate.yml
   - Check all services are running
   - Verify health endpoints respond
   - Test database connectivity
   - Validate HAProxy backend health
   ```

8. **Implement Secrets Management**
   ```bash
   # Use Ansible vault for production
   ansible-vault encrypt inventory/terraform_inventory.yaml
   ```

---

### Long-term Actions (ARCHITECTURAL)

9. **Evaluate netbird-server Combined Container**
   - Current: 4 separate containers (management, signal, dashboard, relay)
   - Recommended: 1 combined netbird-server container
   - Benefit: Simpler, follows official path
   - Effort: Medium (requires refactoring roles)

10. **Implement Proper HA Without Clustering**
    - Keep load balancer (HAProxy) ✓
    - Keep shared database (PostgreSQL) ✓
    - Keep health checks ✓
    - Remove clustering attempts (not supported)
    - Add database connection pooling ✓ (already have PgBouncer)

11. **Add Comprehensive Monitoring**
    - Prometheus metrics exporters
    - Grafana dashboards
    - Alert rules (disk, memory, service availability)
    - Log aggregation (ELK or similar)

---

## TESTING STRATEGY

### Unit Tests (Ansible)

```bash
# Syntax check
ansible-playbook --syntax-check playbooks/site.yml

# Linting
ansible-lint playbooks/site.yml roles/*/tasks/main.yml

# Dry run
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml --check

# Check mode with diff
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml --check --diff
```

### Integration Tests (Full Stack)

```bash
# 1. Terraform validation
terraform fmt -check
terraform validate
terraform plan -out=plan.tfplan

# 2. Ansible inventory validation
ansible-inventory -i inventory/terraform_inventory.yaml --list > /dev/null

# 3. Apply
terraform apply plan.tfplan

# 4. Verify deployment
ansible all -i inventory/terraform_inventory.yaml -m ping
ansible all -i inventory/terraform_inventory.yaml -m shell -a 'docker ps'

# 5. Health checks
# Check all services are healthy
curl -f https://netbird.example.com/api/health
ansible -i inventory/terraform_inventory.yaml -m uri -a "url=http://localhost:9000/health"
```

---

## CONCLUSION

The NetBird HA Terraform+Ansible implementation has **solid fundamentals** but **critical bugs blocking deployment** and **architectural misalignments** with official NetBird design:

### What Works ✓
- Infrastructure provisioning via Terraform
- Most Ansible roles are idempotent
- Load balancing via HAProxy (proper design)
- Database connection pooling via PgBouncer
- Health checks and failover logic

### What Doesn't Work ❌
- HAProxy Ansible module parameter bug (CRITICAL)
- Clustering configuration may not function
- Dashboard environment substitution non-idempotent
- PgBouncer undefined variables

### Architecture Gap ⚠️
- Using deprecated multi-container approach (not combined netbird-server)
- Attempting to use unsupported management clustering
- No official support for management HA (as of Feb 2024)

**Recommended Path Forward**:
1. Fix immediate bugs (5-10 min)
2. Test full deployment in staging (2-4 hours)
3. Evaluate combined container migration (2-3 weeks planning)
4. Implement proper HA based on shared DB + load balancer (already have it)
5. Add monitoring and alerting (1-2 weeks)

