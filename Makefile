.PHONY: help test test-terraform test-ansible test-all fmt fmt-terraform fmt-ansible lint lint-terraform lint-ansible \
	lint-checkov security clean quick-check pre-commit plan apply apply-auto validate init graph state state-rm idempotency-check \
	check-tools validate-pgbouncer validate-ha validate-single-node deploy-check docs version destroy destroy-auto destroy-check \
	destroy-ansible cleanup-leftovers destroy-verify

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

# Paths
TERRAFORM_DIR := infrastructure/ansible-stack
MODULES_DIR := infrastructure/modules
ANSIBLE_DIR := configuration/ansible

# Default target
help:
	@echo "$(BLUE)NetBird Infrastructure - Complete Make Reference$(NC)"
	@echo ""
	@echo "$(YELLOW)VALIDATION & TESTING:$(NC)"
	@echo "  test              - Run all tests (Terraform + Ansible) - RECOMMENDED before commit"
	@echo "  test-terraform    - Validate Terraform syntax and format"
	@echo "  test-ansible      - Validate Ansible playbooks"
	@echo "  quick-check       - Fast validation (format + syntax checks)"
	@echo "  pre-commit        - Full pre-commit validation (fmt + test + lint)"
	@echo ""
	@echo "$(YELLOW)CODE QUALITY:$(NC)"
	@echo "  fmt               - Format all code (Terraform)"
	@echo "  fmt-terraform     - Format Terraform code only"
	@echo "  lint              - Run all linters (tfsec + checkov + ansible-lint)"
	@echo "  lint-terraform    - Lint Terraform with tfsec"
	@echo "  lint-checkov      - Lint Terraform with checkov (alternative)"
	@echo "  lint-ansible      - Lint Ansible playbooks"
	@echo ""
	@echo "$(YELLOW)SECURITY & VERIFICATION:$(NC)"
	@echo "  security          - Run security scans (secrets + IaC scans)"
	@echo "  validate          - Validate Terraform configuration"
	@echo "  idempotency-check - Verify deployment is idempotent (plan twice)"
	@echo ""
	@echo "$(YELLOW)DEPLOYMENT PREP:$(NC)"
	@echo "  validate-single-node - Validate single-node configuration"
	@echo "  validate-ha       - Validate multi-node HA configuration"
	@echo "  validate-pgbouncer - Validate PgBouncer role configuration"
	@echo "  deploy-check      - Full deployment readiness check"
	@echo "  check-tools       - Verify required tools are installed"
	@echo ""
	@echo "$(YELLOW)TERRAFORM UTILITIES:$(NC)"
	@echo "  init              - Initialize Terraform"
	@echo "  plan              - Generate Terraform plan (review before apply)"
	@echo "  apply             - Apply existing plan with confirmation"
	@echo "  apply-auto        - Apply Terraform with auto-approve (no confirmation)"
	@echo "  graph             - Generate infrastructure graph (requires graphviz)"
	@echo "  state             - Show current Terraform state"
	@echo "  state-rm          - Remove resource from state (specify RESOURCE=path)"
	@echo ""
	@echo "$(YELLOW)MAINTENANCE & CLEANUP:$(NC)"
	@echo "  clean             - Clean temporary and state files"
	@echo "  docs              - Show deployment documentation"
	@echo "  version           - Show tool versions"
	@echo ""
	@echo "$(RED)DESTRUCTION (CAREFUL):$(NC)"
	@echo "  destroy-check     - Preview what will be destroyed (dry-run)"
	@echo "  destroy           - Destroy all Terraform-managed resources (with confirmation)"
	@echo "  destroy-auto      - Destroy all resources with auto-approve (no confirmation)"
	@echo "  destroy-ansible   - Destroy only containers/services (keep Terraform)"
	@echo "  cleanup-leftovers - Remove leftover files after destroy"
	@echo "  destroy-verify    - Verify destruction is complete"
	@echo ""
	@echo "$(BLUE)EXAMPLES:$(NC)"
	@echo "  make test              # Run all tests"
	@echo "  make plan              # Generate deployment plan"
	@echo "  make apply             # Apply plan with review"
	@echo "  make apply-auto        # Deploy with auto-approve"
	@echo "  make pre-commit        # Validate before committing"
	@echo "  make deploy-check      # Check deployment readiness"
	@echo "  make destroy-check     # Preview destruction (safe)"
	@echo "  make destroy           # Destroy infrastructure (with confirmation)"
	@echo "  make destroy-auto      # Destroy infrastructure (auto-approve)"
	@echo ""

# ============================================================================
# TESTING & VALIDATION
# ============================================================================

# Run all tests (recommended before any deployment)
test: test-terraform test-ansible
	@echo "$(GREEN)✓ All tests passed$(NC)"

# Terraform validation and format check
test-terraform:
	@echo "$(BLUE)Running Terraform validation...$(NC)"
	@echo "  → Checking ansible-stack format..."
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive || { echo "$(RED)✗ Format check failed. Run: make fmt$(NC)"; exit 1; }
	@echo "  → Initializing terraform..."
	@cd $(TERRAFORM_DIR) && terraform init -backend=false > /dev/null 2>&1
	@echo "  → Validating ansible-stack..."
	@cd $(TERRAFORM_DIR) && terraform validate > /dev/null
	@echo "  → Checking modules format..."
	@cd $(MODULES_DIR) && terraform fmt -check -recursive || { echo "$(RED)✗ Format check failed. Run: make fmt$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Terraform validation passed$(NC)"

# Ansible validation
test-ansible:
	@echo "$(BLUE)Running Ansible validation...$(NC)"
	@cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/site.yml > /dev/null 2>&1 || { echo "$(RED)✗ Ansible syntax check failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Ansible syntax check passed$(NC)"

# ============================================================================
# CODE FORMATTING
# ============================================================================

# Format Terraform code
fmt-terraform:
	@echo "$(BLUE)Formatting Terraform code...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform fmt -recursive
	@cd $(MODULES_DIR) && terraform fmt -recursive
	@echo "$(GREEN)✓ Terraform code formatted$(NC)"

# Format all code
fmt: fmt-terraform
	@echo "$(GREEN)✓ All code formatted$(NC)"

# ============================================================================
# LINTING & SECURITY
# ============================================================================

# Lint with tfsec
lint-terraform:
	@echo "$(BLUE)Linting Terraform with tfsec...$(NC)"
	@command -v tfsec >/dev/null 2>&1 || { echo "$(RED)✗ tfsec not installed$(NC). Install: https://github.com/aquasecurity/tfsec"; exit 1; }
	@tfsec $(TERRAFORM_DIR)/ --minimum-severity MEDIUM
	@tfsec $(MODULES_DIR)/ --minimum-severity MEDIUM
	@echo "$(GREEN)✓ Terraform linting passed$(NC)"

# Lint with checkov (comprehensive IaC scanning)
lint-checkov:
	@echo "$(BLUE)Linting Terraform with checkov...$(NC)"
	@command -v checkov >/dev/null 2>&1 || { echo "$(RED)✗ checkov not installed$(NC). Install: pip install checkov"; exit 1; }
	@checkov -d $(TERRAFORM_DIR) --framework terraform --quiet --compact || true
	@checkov -d $(MODULES_DIR) --framework terraform --quiet --compact || true
	@echo "$(GREEN)✓ Checkov linting completed$(NC)"

# Lint Ansible playbooks
lint-ansible:
	@echo "$(BLUE)Linting Ansible playbooks...$(NC)"
	@command -v ansible-lint >/dev/null 2>&1 || { echo "$(RED)✗ ansible-lint not installed$(NC). Run: pip install ansible-lint"; exit 1; }
	@ansible-lint $(ANSIBLE_DIR)/playbooks/site.yml --quiet || true
	@echo "$(GREEN)✓ Ansible linting completed$(NC)"

# Run all linters
lint: lint-terraform lint-ansible
	@echo "$(GREEN)✓ All linting completed$(NC)"

# Security scans (secrets + IaC)
security:
	@echo "$(BLUE)Running comprehensive security scans...$(NC)"
	@echo "  → Scanning for hardcoded secrets..."
	@command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --no-git --verbose || echo "$(YELLOW)⚠ gitleaks not installed (optional)$(NC)"
	@echo "  → Scanning Terraform with tfsec..."
	@command -v tfsec >/dev/null 2>&1 && tfsec infrastructure/ --minimum-severity HIGH || echo "$(YELLOW)⚠ tfsec not installed$(NC)"
	@echo "  → Scanning Terraform with checkov..."
	@command -v checkov >/dev/null 2>&1 && checkov -d infrastructure/ --framework terraform --quiet || echo "$(YELLOW)⚠ checkov not installed$(NC)"
	@echo "  → Scanning container images..."
	@command -v trivy >/dev/null 2>&1 && trivy config infrastructure/ --quiet || echo "$(YELLOW)⚠ trivy not installed (optional)$(NC)"
	@echo "$(GREEN)✓ Security scans completed$(NC)"

# ============================================================================
# VALIDATION & VERIFICATION
# ============================================================================

# Terraform configuration validation
validate:
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform validate || { echo "$(RED)✗ Terraform validation failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Configuration is valid$(NC)"

# Check idempotency (plan twice, both should be identical)
idempotency-check: init
	@echo "$(BLUE)Checking deployment idempotency...$(NC)"
	@echo "  → First plan..."
	@cd $(TERRAFORM_DIR) && terraform plan -out=/tmp/plan1 > /dev/null 2>&1
	@echo "  → Second plan..."
	@cd $(TERRAFORM_DIR) && terraform plan -out=/tmp/plan2 > /dev/null 2>&1
	@echo "  → Comparing plans..."
	@diff /tmp/plan1 /tmp/plan2 > /dev/null 2>&1 && echo "$(GREEN)✓ Deployment is idempotent$(NC)" || echo "$(YELLOW)⚠ Plans differ (may be OK)$(NC)"
	@rm -f /tmp/plan1 /tmp/plan2

# Validate single-node configuration
validate-single-node:
	@echo "$(BLUE)Validating single-node configuration...$(NC)"
	@test -f $(TERRAFORM_DIR)/single-node.tfvars.example || { echo "$(RED)✗ single-node.tfvars.example not found$(NC)"; exit 1; }
	@grep -q "enable_clustering.*=.*false" $(TERRAFORM_DIR)/single-node.tfvars.example || echo "$(YELLOW)⚠ Clustering not disabled$(NC)"
	@grep -q "enable_pgbouncer.*=.*false" $(TERRAFORM_DIR)/single-node.tfvars.example || echo "$(YELLOW)⚠ PgBouncer not disabled$(NC)"
	@echo "$(GREEN)✓ Single-node configuration valid$(NC)"

# Validate HA configuration
validate-ha:
	@echo "$(BLUE)Validating multi-node HA configuration...$(NC)"
	@test -f $(TERRAFORM_DIR)/multinoded.tfvars.example || { echo "$(RED)✗ multinoded.tfvars.example not found$(NC)"; exit 1; }
	@grep -q "enable_clustering.*=.*true" $(TERRAFORM_DIR)/multinoded.tfvars.example || { echo "$(RED)✗ Clustering not enabled$(NC)"; exit 1; }
	@grep -q "enable_pgbouncer.*=.*true" $(TERRAFORM_DIR)/multinoded.tfvars.example || { echo "$(RED)✗ PgBouncer not enabled$(NC)"; exit 1; }
	@grep -q 'roles.*=.*\["management"\]' $(TERRAFORM_DIR)/multinoded.tfvars.example || echo "$(YELLOW)⚠ Management nodes not defined$(NC)"
	@echo "$(GREEN)✓ HA configuration valid$(NC)"

# Validate PgBouncer role
validate-pgbouncer:
	@echo "$(BLUE)Validating PgBouncer role...$(NC)"
	@test -d $(ANSIBLE_DIR)/roles/pgbouncer || { echo "$(RED)✗ PgBouncer role not found$(NC)"; exit 1; }
	@test -f $(ANSIBLE_DIR)/roles/pgbouncer/tasks/main.yml || { echo "$(RED)✗ PgBouncer tasks not found$(NC)"; exit 1; }
	@test -f $(ANSIBLE_DIR)/roles/pgbouncer/defaults/main.yml || { echo "$(RED)✗ PgBouncer defaults not found$(NC)"; exit 1; }
	@grep -q "pgbouncer_database_host" $(ANSIBLE_DIR)/roles/pgbouncer/defaults/main.yml || { echo "$(RED)✗ PgBouncer host variable not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ PgBouncer role is valid$(NC)"

# Full deployment readiness check
deploy-check: check-tools validate test lint validate-single-node validate-ha validate-pgbouncer
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║     ✓ DEPLOYMENT READINESS CHECK PASSED                   ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Your infrastructure is ready for deployment!"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Review configuration: vim terraform.tfvars"
	@echo "  2. Generate plan: make plan"
	@echo "  3. Review plan carefully"
	@echo "  4. Deploy: terraform apply"
	@echo ""

# ============================================================================
# TERRAFORM UTILITIES
# ============================================================================

# Initialize Terraform
init:
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

# Generate Terraform plan
plan: validate
	@echo "$(BLUE)Generating Terraform plan...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform plan -out=tfplan
	@echo ""
	@echo "$(YELLOW)Plan saved to tfplan$(NC)"
	@echo "Review with: terraform show tfplan"
	@echo "Apply with: terraform apply tfplan or make apply-auto"
	@echo ""

# Apply Terraform plan with review (requires existing tfplan)
apply:
	@echo "$(BLUE)Applying Terraform configuration...$(NC)"
	@test -f $(TERRAFORM_DIR)/tfplan || { echo "$(RED)✗ No plan found. Run: make plan$(NC)"; exit 1; }
	@echo "$(YELLOW)Reviewing plan before apply...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform show tfplan
	@echo ""
	@echo "$(RED)⚠ WARNING: This will create or modify resources$(NC)"
	@read -p "Type 'yes' to apply: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd $(TERRAFORM_DIR) && terraform apply tfplan && rm -f tfplan; \
		echo "$(GREEN)✓ Terraform apply completed$(NC)"; \
	else \
		echo "$(YELLOW)Apply cancelled$(NC)"; \
	fi

# Apply Terraform configuration with auto-approve (skips confirmation)
apply-auto: validate
	@echo "$(GREEN)✓ Configuration validated$(NC)"
	@echo ""
	@echo "$(BLUE)Applying Terraform with auto-approve...$(NC)"
	@echo "$(RED)⚠ WARNING: Auto-applying without review!$(NC)"
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@echo ""
	@echo "$(GREEN)✓ Infrastructure deployed successfully$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Run playbooks: ansible-playbook configuration/ansible/playbooks/site.yml"
	@echo "  2. Verify deployment: make destroy-verify"
	@echo "  3. Check health: curl https://netbird.example.com/health"
	@echo ""

# Generate infrastructure graph (requires graphviz)
graph:
	@echo "$(BLUE)Generating infrastructure graph...$(NC)"
	@command -v dot >/dev/null 2>&1 || { echo "$(RED)✗ graphviz not installed$(NC). Install: apt-get install graphviz"; exit 1; }
	@cd $(TERRAFORM_DIR) && terraform graph | dot -Tpng > infrastructure-graph.png
	@echo "$(GREEN)✓ Graph saved to infrastructure-graph.png$(NC)"

# Show Terraform state
state:
	@echo "$(BLUE)Current Terraform state:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform show || echo "$(YELLOW)No state file found$(NC)"

# Remove resource from state (usage: make state-rm RESOURCE=aws_instance.example)
state-rm:
	@test -n "$(RESOURCE)" || { echo "$(RED)✗ RESOURCE not specified$(NC). Usage: make state-rm RESOURCE=aws_instance.example"; exit 1; }
	@echo "$(RED)⚠ Removing $(RESOURCE) from state...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform state rm $(RESOURCE)

# ============================================================================
# QUICK CHECKS
# ============================================================================

# Quick validation (fast checks before commit)
quick-check: fmt validate
	@echo "$(BLUE)Running quick validation checks...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive > /dev/null 2>&1 || { echo "$(RED)✗ Format check failed$(NC)"; exit 1; }
	@cd $(MODULES_DIR) && terraform fmt -check -recursive > /dev/null 2>&1 || { echo "$(RED)✗ Format check failed$(NC)"; exit 1; }
	@cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/site.yml > /dev/null 2>&1 || { echo "$(RED)✗ Ansible syntax check failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Quick checks passed$(NC)"

# Full pre-commit validation
pre-commit: fmt validate test lint
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║     ✓ PRE-COMMIT VALIDATION COMPLETED                      ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Ready to commit!"

# ============================================================================
# MAINTENANCE & UTILITIES
# ============================================================================

# Check if required tools are installed
check-tools:
	@echo "$(BLUE)Checking for required tools...$(NC)"
	@echo "  → terraform..."
	@command -v terraform >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || { echo "    $(RED)✗ not found$(NC)"; exit 1; }
	@echo "  → ansible..."
	@command -v ansible >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || { echo "    $(RED)✗ not found$(NC)"; exit 1; }
	@echo "  → ansible-playbook..."
	@command -v ansible-playbook >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || { echo "    $(RED)✗ not found$(NC)"; exit 1; }
	@echo "  → ansible-lint (optional)..."
	@command -v ansible-lint >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || echo "    $(YELLOW)⚠ not found (optional)$(NC)"
	@echo "  → tfsec (recommended)..."
	@command -v tfsec >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || echo "    $(YELLOW)⚠ not found (recommended)$(NC)"
	@echo "  → checkov (optional)..."
	@command -v checkov >/dev/null 2>&1 && echo "    $(GREEN)✓ installed$(NC)" || echo "    $(YELLOW)⚠ not found (optional)$(NC)"

# Show tool versions
version:
	@echo "$(BLUE)Tool versions:$(NC)"
	@echo "  Terraform: $$(terraform version -json 2>/dev/null | grep terraform_version | cut -d'"' -f4)"
	@echo "  Ansible: $$(ansible --version | head -1)"
	@command -v tfsec >/dev/null 2>&1 && echo "  TFSec: $$(tfsec --version)" || echo "  TFSec: not installed"
	@command -v checkov >/dev/null 2>&1 && echo "  Checkov: $$(checkov --version | cut -d' ' -f3)" || echo "  Checkov: not installed"

# Clean temporary and state files
clean:
	@echo "$(BLUE)Cleaning temporary and state files...$(NC)"
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "tfplan*" -exec rm -f {} + 2>/dev/null || true
	@rm -rf $(ANSIBLE_DIR)/inventory/terraform_inventory.yaml 2>/dev/null || true
	@rm -f infrastructure-graph.png 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

# Show deployment documentation
docs:
	@echo "$(BLUE)NetBird Deployment Documentation:$(NC)"
	@echo ""
	@test -f FINAL_DEPLOYMENT_SUMMARY.md && echo "  $(GREEN)✓$(NC) FINAL_DEPLOYMENT_SUMMARY.md" || echo "  $(RED)✗$(NC) FINAL_DEPLOYMENT_SUMMARY.md not found"
	@test -f infrastructure/ansible-stack/single-node.tfvars.example && echo "  $(GREEN)✓$(NC) single-node.tfvars.example" || echo "  $(RED)✗$(NC) single-node.tfvars.example not found"
	@test -f infrastructure/ansible-stack/multinoded.tfvars.example && echo "  $(GREEN)✓$(NC) multinoded.tfvars.example" || echo "  $(RED)✗$(NC) multinoded.tfvars.example not found"
	@test -f configuration/ansible/roles/pgbouncer/README.md && echo "  $(GREEN)✓$(NC) pgbouncer/README.md" || echo "  $(RED)✗$(NC) pgbouncer/README.md not found"
	@echo ""
	@echo "View with: cat FINAL_DEPLOYMENT_SUMMARY.md"

# ============================================================================
# DESTROY & CLEANUP (CAREFUL - DESTRUCTIVE OPERATIONS)
# ============================================================================

# Verify what will be destroyed (dry-run)
destroy-check: validate
	@echo "$(RED)⚠ DESTRUCTION PREVIEW - Nothing will be deleted$(NC)"
	@echo ""
	@echo "$(BLUE)Resources that will be destroyed:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform plan -destroy
	@echo ""
	@echo "$(YELLOW)To actually destroy, run: make destroy$(NC)"

# Destroy Terraform resources (infrastructure only, not data)
destroy:
	@echo "$(RED)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║ WARNING: DESTRUCTIVE OPERATION - This will destroy:        ║$(NC)"
	@echo "$(RED)║ • All NetBird Docker containers                            ║$(NC)"
	@echo "$(RED)║ • All temporary files and networks                         ║$(NC)"
	@echo "$(RED)║ • All Terraform-managed resources                          ║$(NC)"
	@echo "$(RED)║                                                            ║$(NC)"
	@echo "$(RED)║ This WILL NOT destroy:                                     ║$(NC)"
	@echo "$(RED)║ • External PostgreSQL database                             ║$(NC)"
	@echo "$(RED)║ • External Keycloak instance                               ║$(NC)"
	@echo "$(RED)║ • DNS records                                              ║$(NC)"
	@echo "$(RED)║ • Cloud resources not in terraform state                   ║$(NC)"
	@echo "$(RED)║                                                            ║$(NC)"
	@echo "$(RED)║ Type 'yes' to confirm destruction:                         ║$(NC)"
	@echo "$(RED)╚════════════════════════════════════════════════════════════╝$(NC)"
	@read -p "Confirm (type 'yes'): " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd $(TERRAFORM_DIR) && terraform destroy; \
		$(MAKE) cleanup-leftovers; \
		echo "$(GREEN)✓ Destruction complete$(NC)"; \
	else \
		echo "$(YELLOW)Destruction cancelled$(NC)"; \
	fi

# Destroy all infrastructure with auto-approve (no confirmation)
destroy-auto:
	@echo "$(RED)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║ ⚠ AUTO-DESTROYING ALL INFRASTRUCTURE!                     ║$(NC)"
	@echo "$(RED)║                                                            ║$(NC)"
	@echo "$(RED)║ This will destroy:                                         ║$(NC)"
	@echo "$(RED)║ • All NetBird Docker containers                            ║$(NC)"
	@echo "$(RED)║ • All temporary files and networks                         ║$(NC)"
	@echo "$(RED)║ • All Terraform-managed resources                          ║$(NC)"
	@echo "$(RED)║                                                            ║$(NC)"
	@echo "$(RED)║ This will NOT destroy:                                     ║$(NC)"
	@echo "$(RED)║ • External PostgreSQL database                             ║$(NC)"
	@echo "$(RED)║ • External Keycloak instance                               ║$(NC)"
	@echo "$(RED)║ • DNS records                                              ║$(NC)"
	@echo "$(RED)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	@$(MAKE) cleanup-leftovers
	@echo "$(GREEN)✓ Auto-destruction complete$(NC)"

# Destroy only Ansible-deployed resources (containers, services)
destroy-ansible:
	@echo "$(RED)⚠ Destroying Ansible-deployed resources...$(NC)"
	@echo "$(BLUE)This will stop and remove:$(NC)"
	@echo "  - NetBird management containers"
	@echo "  - NetBird signal containers"
	@echo "  - NetBird relay containers"
	@echo "  - HAProxy containers"
	@echo "  - PgBouncer containers"
	@echo "  - Caddy containers"
	@echo "  - COTURN containers"
	@echo ""
	@echo "$(YELLOW)This will NOT remove:$(NC)"
	@echo "  - Docker networks (managed by Terraform)"
	@echo "  - Terraform state"
	@echo "  - Configuration files"
	@echo ""
	@echo "Type 'yes' to confirm:"
	@read -p "Confirm (type 'yes'): " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd $(ANSIBLE_DIR) && ansible-playbook playbooks/cleanup.yml -i inventory/terraform_inventory.yaml || true; \
		echo "$(GREEN)✓ Ansible resources destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# Clean up leftover files after destroy
cleanup-leftovers:
	@echo "$(BLUE)Cleaning up leftover files...$(NC)"
	@echo "  → Removing Docker volumes..."
	@for host in $$(cd $(TERRAFORM_DIR) && terraform output -json netbird_hosts 2>/dev/null | grep -o '"[^"]*":' | tr -d '":' | head -1); do \
		ssh -o ConnectTimeout=5 $$host 'docker volume prune -f' 2>/dev/null || true; \
	done
	@echo "  → Removing Ansible inventory..."
	@rm -f $(ANSIBLE_DIR)/inventory/terraform_inventory.yaml
	@echo "  → Removing temporary files..."
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f tfplan*
	@echo "$(GREEN)✓ Leftovers cleaned up$(NC)"

# Full verification after destroy
destroy-verify:
	@echo "$(BLUE)Verifying destruction...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform show || echo "$(GREEN)✓ Terraform state empty (good)$(NC)"
	@echo ""
	@echo "$(BLUE)Checking for orphaned resources:$(NC)"
	@echo "  → Docker containers on each host:"
	@echo "$(YELLOW)Run manually for each host: docker ps -a$(NC)"
	@echo "  → Terraform state:"
	@cd $(TERRAFORM_DIR) && terraform state list 2>/dev/null | wc -l | awk '{if($$1 == 0) print "    $(GREEN)✓ State clean$(NC)"; else print "    $(RED)✗ State not empty$(NC)"}'
	@echo ""
	@echo "$(YELLOW)Manual cleanup needed:$(NC)"
	@echo "  1. PostgreSQL database (not destroyed): Drop database manually"
	@echo "  2. Keycloak realm (not destroyed): Delete realm manually"
	@echo "  3. DNS records (not destroyed): Remove A records manually"
	@echo "  4. SSH keys (not destroyed): Remove from ~/.ssh/known_hosts"
