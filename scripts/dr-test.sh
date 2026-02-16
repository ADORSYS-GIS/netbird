#!/usr/bin/env bash
set -euo pipefail

echo "================================================"
echo "NetBird Disaster Recovery Test"
echo "================================================"
echo ""
echo "⚠️  WARNING: This script simulates disaster recovery"
echo "    procedures. Use with caution in production!"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/tmp/netbird-dr-test}"
TERRAFORM_DIR="${TERRAFORM_DIR:-infrastructure}"
INVENTORY_FILE="${INVENTORY_FILE:-configuration/inventory/terraform_inventory.yaml}"

# Functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
    echo "Checking prerequisites..."
    local missing=0
    
    for cmd in terraform ansible-playbook pg_dump tar; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd found"
        else
            log_error "$cmd not found"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "Missing $missing required tools"
        exit 1
    fi
}

backup_terraform_state() {
    echo ""
    echo "================================================"
    echo "1. Backup Terraform State"
    echo "================================================"
    
    mkdir -p "$BACKUP_DIR/terraform"
    
    if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/terraform/terraform.tfstate.backup"
        log_info "Local state backed up"
    else
        log_warn "No local terraform.tfstate found (using remote backend?)"
    fi
    
    # Backup state from remote backend
    if cd "$TERRAFORM_DIR" && terraform state pull > "$BACKUP_DIR/terraform/remote-state.tfstate" 2>/dev/null; then
        log_info "Remote state backed up"
    else
        log_warn "Could not pull remote state (backend not initialized?)"
    fi
    
    cd - >/dev/null
}

backup_configuration() {
    echo ""
    echo "================================================"
    echo "2. Backup Configuration Files"
    echo "================================================"
    
    mkdir -p "$BACKUP_DIR/config"
    
    # Backup Terraform configs
    tar -czf "$BACKUP_DIR/config/terraform-configs.tar.gz" \
        -C "$TERRAFORM_DIR" \
        --exclude='.terraform' \
        --exclude='*.tfstate*' \
        . 2>/dev/null || log_warn "No Terraform configs to backup"
    
    log_info "Terraform configs backed up"
    
    # Backup Ansible configs
    tar -czf "$BACKUP_DIR/config/ansible-configs.tar.gz" \
        configuration/ 2>/dev/null || log_warn "No Ansible configs to backup"
    
    log_info "Ansible configs backed up"
    
    # Backup inventory (if exists)
    if [ -f "$INVENTORY_FILE" ]; then
        cp "$INVENTORY_FILE" "$BACKUP_DIR/config/inventory.yaml.backup"
        log_info "Inventory file backed up"
    else
        log_warn "No inventory file found (not yet generated?)"
    fi
}

simulate_database_backup() {
    echo ""
    echo "================================================"
    echo "3. Database Backup (Simulated)"
    echo "================================================"
    
    mkdir -p "$BACKUP_DIR/database"
    
    log_warn "Database backup requires connection credentials"
    log_info "Example PostgreSQL backup command:"
    echo "    pg_dump -h <host> -U netbird -d netbird_db > backup.sql"
    
    log_info "Example SQLite backup command:"
    echo "    cp /var/lib/netbird/store.db $BACKUP_DIR/database/store.db.backup"
    
    log_info "For actual DR, automate with:"
    echo "    - RDS automated backups (AWS)"
    echo "    - Cloud SQL automated backups (GCP)"
    echo "    - Azure Database automated backups (Azure)"
}

verify_backup_integrity() {
    echo ""
    echo "================================================"
    echo "4. Verify Backup Integrity"
    echo "================================================"
    
    local files_ok=0
    local files_missing=0
    
    # Check backed up files
    expected_files=(
        "$BACKUP_DIR/config/terraform-configs.tar.gz"
        "$BACKUP_DIR/config/ansible-configs.tar.gz"
    )
    
    for file in "${expected_files[@]}"; do
        if [ -f "$file" ]; then
            size=$(du -h "$file" | cut -f1)
            log_info "$(basename "$file"): $size"
            files_ok=$((files_ok + 1))
        else
            log_warn "$(basename "$file"): Not found"
            files_missing=$((files_missing + 1))
        fi
    done
    
    echo ""
    log_info "Backup integrity check: $files_ok OK, $files_missing missing"
}

test_restore_procedure() {
    echo ""
    echo "================================================"
    echo "5. Test Restore Procedure (Dry Run)"
    echo "================================================"
    
    log_warn "Restore procedure test (not executing, just showing steps):"
    echo ""
    echo "Step 1: Restore Terraform state"
    echo "    terraform state push $BACKUP_DIR/terraform/remote-state.tfstate"
    echo ""
    echo "Step 2: Extract configuration"
    echo "    tar -xzf $BACKUP_DIR/config/terraform-configs.tar.gz -C $TERRAFORM_DIR"
    echo "    tar -xzf $BACKUP_DIR/config/ansible-configs.tar.gz -C ."
    echo ""
    echo "Step 3: Restore database (PostgreSQL example)"
    echo "    psql -h <host> -U netbird -d netbird_db < backup.sql"
    echo ""
    echo "Step 4: Re-apply infrastructure"
    echo "    cd $TERRAFORM_DIR && terraform apply"
    echo ""
    echo "Step 5: Re-configure servers"
    echo "    ansible-playbook -i $INVENTORY_FILE configuration/playbooks/site.yml"
    
    log_info "Restore procedure documented"
}

generate_dr_report() {
    echo ""
    echo "================================================"
    echo "6. Generate DR Report"
    echo "================================================"
    
    local report="$BACKUP_DIR/dr-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "NetBird Disaster Recovery Test Report"
        echo "======================================="
        echo "Date: $(date)"
        echo "Backup Location: $BACKUP_DIR"
        echo ""
        echo "Backed Up Components:"
        ls -lh "$BACKUP_DIR"/* 2>/dev/null || echo "None"
        echo ""
        echo "Recovery Time Objective (RTO): 2 hours (target)"
        echo "Recovery Point Objective (RPO): 24 hours (daily backups)"
        echo ""
        echo "Next Steps:"
        echo "1. Test restore in isolated environment"
        echo "2. Document restore times"
        echo "3. Update DR runbook with actual procedures"
        echo "4. Schedule quarterly DR drills"
    } > "$report"
    
    log_info "DR report generated: $report"
    cat "$report"
}

cleanup_test_backups() {
    echo ""
    echo "================================================"
    echo "7. Cleanup Test Backups"
    echo "================================================"
    
    read -p "Delete test backups in $BACKUP_DIR? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$BACKUP_DIR"
        log_info "Test backups deleted"
    else
        log_info "Test backups preserved in: $BACKUP_DIR"
    fi
}

# Main execution
main() {
    check_prerequisites
    backup_terraform_state
    backup_configuration
    simulate_database_backup
    verify_backup_integrity
    test_restore_procedure
    generate_dr_report
    cleanup_test_backups
    
    echo ""
    echo "================================================"
    echo "DR Test Completed"
    echo "================================================"
    log_info "Review the generated report for next steps"
}

main "$@"
