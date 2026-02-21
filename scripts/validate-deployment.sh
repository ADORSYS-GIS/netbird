#!/bin/bash
# NetBird HA Deployment Validation Script
# Validates Terraform and Ansible configuration before deployment
# Usage: ./scripts/validate-deployment.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$PROJECT_ROOT/infrastructure/ansible-stack"
CONFIG_DIR="$PROJECT_ROOT/configuration/ansible"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}NetBird HA Deployment Validation Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if terraform.tfvars exists
echo -e "${YELLOW}[1/8] Checking terraform.tfvars...${NC}"
if [[ ! -f "$INFRA_DIR/terraform.tfvars" ]]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found. Copy from example:${NC}"
    echo "  cp $INFRA_DIR/multinoded.tfvars.example $INFRA_DIR/terraform.tfvars"
    echo "  vim $INFRA_DIR/terraform.tfvars"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓ terraform.tfvars found${NC}"
    PASSED=$((PASSED + 1))
fi
echo ""

# Terraform format check
echo -e "${YELLOW}[2/8] Checking Terraform code formatting...${NC}"
cd "$INFRA_DIR"
if terraform fmt -check -recursive > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform formatting OK${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Terraform formatting issues found${NC}"
    echo "  Fix with: terraform fmt -recursive"
    FAILED=$((FAILED + 1))
fi
echo ""

# Terraform validation
echo -e "${YELLOW}[3/8] Validating Terraform syntax...${NC}"
if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform syntax valid${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Terraform syntax errors found${NC}"
    terraform validate
    FAILED=$((FAILED + 1))
fi
echo ""

# Check for HAProxy 'env' parameter fix
echo -e "${YELLOW}[4/8] Checking HAProxy 'env' parameter fix...${NC}"
HAPROXY_FILE="$CONFIG_DIR/roles/haproxy/tasks/main.yml"
if grep -q "^    env:" "$HAPROXY_FILE"; then
    echo -e "${GREEN}✓ HAProxy using 'env' parameter (FIXED)${NC}"
    PASSED=$((PASSED + 1))
elif grep -q "^    environment:" "$HAPROXY_FILE"; then
    echo -e "${RED}✗ HAProxy still using 'environment' parameter (BUG NOT FIXED)${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${YELLOW}⚠️  Could not find env/environment parameter${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check PgBouncer variables defined
echo -e "${YELLOW}[5/8] Checking PgBouncer health check variables...${NC}"
GROUP_VARS="$CONFIG_DIR/group_vars/all.yml"
if grep -q "pgbouncer_health_check_period:" "$GROUP_VARS" && \
   grep -q "pgbouncer_health_check_timeout:" "$GROUP_VARS"; then
    echo -e "${GREEN}✓ PgBouncer health check variables defined${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ PgBouncer health check variables missing${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Check Dashboard idempotency fix
echo -e "${YELLOW}[6/8] Checking Dashboard idempotency fix...${NC}"
DASHBOARD_FILE="$CONFIG_DIR/roles/netbird-dashboard/tasks/main.yml"
if grep -q "changed_when: false" "$DASHBOARD_FILE"; then
    echo -e "${GREEN}✓ Dashboard task uses 'changed_when: false'${NC}"
    PASSED=$((PASSED + 1))
elif grep -q "changed_when: true" "$DASHBOARD_FILE"; then
    echo -e "${RED}✗ Dashboard task still uses 'changed_when: true' (BUG NOT FIXED)${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${YELLOW}⚠️  Could not find changed_when in dashboard task${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check PgBouncer lineinfile regex fix
echo -e "${YELLOW}[7/8] Checking PgBouncer lineinfile idempotency fix...${NC}"
PGBOUNCER_FILE="$CONFIG_DIR/roles/pgbouncer/tasks/main.yml"
if grep -q "regexp:" "$PGBOUNCER_FILE"; then
    echo -e "${GREEN}✓ PgBouncer lineinfile uses regexp (FIXED)${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ PgBouncer lineinfile missing regexp parameter${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Ansible syntax check
echo -e "${YELLOW}[8/8] Checking Ansible playbook syntax...${NC}"
cd "$CONFIG_DIR"
INVENTORY_CHECK=false
if [[ -f "inventory/terraform_inventory.yaml" ]]; then
    INVENTORY_FILE="inventory/terraform_inventory.yaml"
    INVENTORY_CHECK=true
else
    # Create a dummy inventory for syntax check
    INVENTORY_FILE="/tmp/dummy_inventory.yaml"
    cat > "$INVENTORY_FILE" << 'EOF'
all:
  vars:
    netbird_domain: "example.com"
    netbird_version: "0.27.0"
    database_engine: "postgres"
    keycloak_url: "https://example.com"
    enable_pgbouncer: true
    enable_clustering: false
  children:
    management:
      hosts:
        node-1:
          ansible_host: "127.0.0.1"
EOF
fi

if ansible-playbook --syntax-check -i "$INVENTORY_FILE" playbooks/site.yml > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ansible playbook syntax valid${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Ansible syntax errors found${NC}"
    ansible-playbook --syntax-check -i "$INVENTORY_FILE" playbooks/site.yml
    FAILED=$((FAILED + 1))
fi

# Cleanup dummy inventory if created
if [[ "$INVENTORY_CHECK" == false ]]; then
    rm -f "$INVENTORY_FILE"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}VALIDATION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical validations passed!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review terraform.tfvars configuration"
    echo "2. Run: cd $INFRA_DIR && terraform plan -out=plan.tfplan"
    echo "3. Review the plan output"
    echo "4. Run: terraform apply plan.tfplan"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Validation failed. Please fix the issues above.${NC}"
    echo ""
    exit 1
fi
