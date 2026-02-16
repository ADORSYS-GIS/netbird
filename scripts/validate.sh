#!/usr/bin/env bash
set -euo pipefail

echo "================================================"
echo "NetBird Infrastructure Validation"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

run_check() {
    local name="$1"
    shift
    echo ""
    echo "Running: $name"
    echo "----------------------------------------"
    
    if "$@"; then
        echo -e "${GREEN}✓${NC} $name passed"
    else
        echo -e "${RED}✗${NC} $name failed"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "Checking prerequisites..."
echo "----------------------------------------"
check_command terraform || FAILURES=$((FAILURES + 1))
check_command ansible || FAILURES=$((FAILURES + 1))
check_command ansible-playbook || FAILURES=$((FAILURES + 1))

echo ""
echo "Optional tools:"
check_command tfsec || echo -e "${YELLOW}⚠${NC}  Install: brew install tfsec (or see https://github.com/aquasecurity/tfsec)"
check_command ansible-lint || echo -e "${YELLOW}⚠${NC}  Install: pip install ansible-lint"
check_command gitleaks || echo -e "${YELLOW}⚠${NC}  Install: brew install gitleaks"

echo ""
echo "================================================"
echo "Terraform Validation"
echo "================================================"

run_check "Terraform Format Check" \
    terraform -chdir=infrastructure fmt -check -recursive

run_check "Terraform Init (backend disabled)" \
    terraform -chdir=infrastructure init -backend=false

run_check "Terraform Validate" \
    terraform -chdir=infrastructure validate

if command -v tfsec >/dev/null 2>&1; then
    run_check "Terraform Security Scan (tfsec)" \
        tfsec infrastructure/ --minimum-severity HIGH
else
    echo -e "${YELLOW}⚠${NC}  Skipping tfsec (not installed)"
fi

echo ""
echo "================================================"
echo "Ansible Validation"
echo "================================================"

run_check "Ansible Syntax Check" \
    ansible-playbook --syntax-check configuration/playbooks/site.yml

if command -v ansible-lint >/dev/null 2>&1; then
    echo ""
    echo "Running: Ansible Lint"
    echo "----------------------------------------"
    ansible-lint configuration/playbooks/site.yml || echo -e "${YELLOW}⚠${NC}  Ansible lint found issues (non-blocking)"
else
    echo -e "${YELLOW}⚠${NC}  Skipping ansible-lint (not installed)"
fi

echo ""
echo "================================================"
echo "Security Scans"
echo "================================================"

if command -v gitleaks >/dev/null 2>&1; then
    run_check "Secret Scanning (gitleaks)" \
        gitleaks detect --source . --no-git --verbose
else
    echo -e "${YELLOW}⚠${NC}  Skipping gitleaks (not installed)"
fi

echo ""
echo "================================================"
echo "Summary"
echo "================================================"

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILURES validation check(s) failed${NC}"
    exit 1
fi
