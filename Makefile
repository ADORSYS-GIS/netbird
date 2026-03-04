.PHONY: help init validate plan apply deploy test clean destroy \
	fmt lint security check-tools version \
	test-terraform test-ansible validate-config \
	deploy-ansible deploy-full status health \
	backup restore upgrade rollback

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m

# Paths
TERRAFORM_DIR := infrastructure/ansible-stack
ANSIBLE_DIR := configuration/ansible
INVENTORY := $(ANSIBLE_DIR)/inventory/terraform_inventory.yaml

# Default target
.DEFAULT_GOAL := help

help:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  NetBird Infrastructure - Production Deployment$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)QUICK START:$(NC)"
	@echo "  make init          Initialize Terraform"
	@echo "  make validate      Validate configuration"
	@echo "  make plan          Preview infrastructure changes"
	@echo "  make apply         Apply infrastructure (Terraform only)"
	@echo "  make deploy        Full deployment (Terraform + Ansible)"
	@echo ""
	@echo "$(CYAN)TESTING & VALIDATION:$(NC)"
	@echo "  make test          Run all tests"
	@echo "  make test-terraform Validate Terraform"
	@echo "  make test-ansible  Validate Ansible playbooks"
	@echo "  make validate-config Check configuration files"
	@echo "  make security      Run security scans"
	@echo ""
	@echo "$(CYAN)CODE QUALITY:$(NC)"
	@echo "  make fmt           Format all code"
	@echo "  make lint          Run all linters"
	@echo "  make check-tools   Verify required tools"
	@echo ""
	@echo "$(CYAN)DEPLOYMENT:$(NC)"
	@echo "  make deploy-ansible Deploy with Ansible only"
	@echo "  make deploy-full   Full deployment (recommended)"
	@echo "  make status        Check deployment status"
	@echo "  make health        Health check all services"
	@echo ""
	@echo "$(CYAN)MAINTENANCE:$(NC)"
	@echo "  make backup        Backup configuration"
	@echo "  make upgrade       Upgrade NetBird version"
	@echo "  make rollback      Rollback to previous version"
	@echo ""
	@echo "$(CYAN)CLEANUP:$(NC)"
	@echo "  make clean         Clean temporary files"
	@echo "  make destroy       Destroy infrastructure"
	@echo ""
	@echo "$(CYAN)UTILITIES:$(NC)"
	@echo "  make version       Show tool versions"
	@echo "  make help          Show this help"
	@echo ""

# ═══════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════

init:
	@echo "$(BLUE)→ Initializing Terraform...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

# ═══════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════

validate: check-tools
	@echo "$(BLUE)→ Validating Terraform configuration...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform validate
	@echo "$(GREEN)✓ Terraform configuration valid$(NC)"

validate-config:
	@echo "$(BLUE)→ Validating configuration files...$(NC)"
	@test -f $(TERRAFORM_DIR)/terraform.tfvars || { echo "$(RED)✗ terraform.tfvars not found$(NC)"; exit 1; }
	@grep -q "netbird_domain" $(TERRAFORM_DIR)/terraform.tfvars || { echo "$(RED)✗ netbird_domain not set$(NC)"; exit 1; }
	@grep -q "keycloak_url" $(TERRAFORM_DIR)/terraform.tfvars || { echo "$(RED)✗ keycloak_url not set$(NC)"; exit 1; }
	@grep -q "existing_postgresql_host" $(TERRAFORM_DIR)/terraform.tfvars || { echo "$(YELLOW)⚠ Using SQLite (PostgreSQL not configured)$(NC)"; }
	@echo "$(GREEN)✓ Configuration files valid$(NC)"

test: test-terraform test-ansible
	@echo "$(GREEN)✓ All tests passed$(NC)"

test-terraform:
	@echo "$(BLUE)→ Testing Terraform...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive
	@cd $(TERRAFORM_DIR) && terraform validate
	@echo "$(GREEN)✓ Terraform tests passed$(NC)"

test-ansible:
	@echo "$(BLUE)→ Testing Ansible...$(NC)"
	@test -f $(INVENTORY) || { echo "$(YELLOW)⚠ Inventory not generated yet (run: make apply)$(NC)"; exit 0; }
	@cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/site.yml
	@echo "$(GREEN)✓ Ansible tests passed$(NC)"

# ═══════════════════════════════════════════════════════════════
# CODE QUALITY
# ═══════════════════════════════════════════════════════════════

fmt:
	@echo "$(BLUE)→ Formatting code...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform fmt -recursive
	@cd infrastructure/modules && terraform fmt -recursive
	@echo "$(GREEN)✓ Code formatted$(NC)"

lint:
	@echo "$(BLUE)→ Running linters...$(NC)"
	@command -v tfsec >/dev/null 2>&1 && tfsec $(TERRAFORM_DIR) --minimum-severity MEDIUM || echo "$(YELLOW)⚠ tfsec not installed$(NC)"
	@command -v ansible-lint >/dev/null 2>&1 && ansible-lint $(ANSIBLE_DIR)/playbooks/site.yml || echo "$(YELLOW)⚠ ansible-lint not installed$(NC)"
	@echo "$(GREEN)✓ Linting complete$(NC)"

security:
	@echo "$(BLUE)→ Running security scans...$(NC)"
	@command -v tfsec >/dev/null 2>&1 && tfsec infrastructure/ --minimum-severity HIGH || echo "$(YELLOW)⚠ tfsec not installed$(NC)"
	@command -v checkov >/dev/null 2>&1 && checkov -d infrastructure/ --framework terraform --quiet || echo "$(YELLOW)⚠ checkov not installed$(NC)"
	@echo "$(GREEN)✓ Security scans complete$(NC)"

check-tools:
	@echo "$(BLUE)→ Checking required tools...$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)✗ terraform not found$(NC)"; exit 1; }
	@command -v ansible >/dev/null 2>&1 || { echo "$(RED)✗ ansible not found$(NC)"; exit 1; }
	@command -v ansible-playbook >/dev/null 2>&1 || { echo "$(RED)✗ ansible-playbook not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All required tools installed$(NC)"

version:
	@echo "$(BLUE)Tool Versions:$(NC)"
	@echo "  Terraform: $$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"
	@echo "  Ansible: $$(ansible --version | head -1 | awk '{print $$2}')"
	@command -v tfsec >/dev/null 2>&1 && echo "  TFSec: $$(tfsec --version | head -1)" || echo "  TFSec: not installed"

# ═══════════════════════════════════════════════════════════════
# INFRASTRUCTURE DEPLOYMENT
# ═══════════════════════════════════════════════════════════════

plan: validate validate-config
	@echo "$(BLUE)→ Generating Terraform plan...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform plan -out=tfplan
	@echo ""
	@echo "$(YELLOW)Plan saved to tfplan$(NC)"
	@echo "Review and apply with: $(CYAN)make apply$(NC)"

apply: validate
	@echo "$(BLUE)→ Applying Terraform configuration...$(NC)"
	@test -f $(TERRAFORM_DIR)/tfplan && cd $(TERRAFORM_DIR) && terraform apply tfplan && rm -f tfplan || \
		cd $(TERRAFORM_DIR) && terraform apply
	@echo "$(GREEN)✓ Infrastructure deployed$(NC)"
	@echo ""
	@echo "$(CYAN)Next step: Deploy services with Ansible$(NC)"
	@echo "  Run: $(YELLOW)make deploy-ansible$(NC)"

# ═══════════════════════════════════════════════════════════════
# APPLICATION DEPLOYMENT
# ═══════════════════════════════════════════════════════════════

deploy-ansible:
	@echo "$(BLUE)→ Deploying NetBird with Ansible...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Inventory not found. Run: make apply$(NC)"; exit 1; }
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/site.yml
	@echo "$(GREEN)✓ NetBird deployed$(NC)"
	@echo ""
	@echo "$(CYAN)Deployment complete!$(NC)"
	@echo "  Dashboard: https://$$(grep netbird_domain $(TERRAFORM_DIR)/terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"

deploy-full: apply deploy-ansible
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  ✓ Full Deployment Complete$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@$(MAKE) status

deploy: deploy-full

# ═══════════════════════════════════════════════════════════════
# MONITORING & STATUS
# ═══════════════════════════════════════════════════════════════

status:
	@echo "$(BLUE)→ Checking deployment status...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Not deployed yet$(NC)"; exit 1; }
	@echo ""
	@echo "$(CYAN)Infrastructure:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform output -json | grep -q "management_nodes" && echo "  $(GREEN)✓$(NC) Terraform state exists" || echo "  $(RED)✗$(NC) No Terraform state"
	@echo ""
	@echo "$(CYAN)Services:$(NC)"
	@cd $(ANSIBLE_DIR) && ansible management -i $(INVENTORY) -m shell -a "docker ps --format '{{.Names}}' | grep netbird" 2>/dev/null | grep -q "netbird" && echo "  $(GREEN)✓$(NC) Management containers running" || echo "  $(YELLOW)⚠$(NC) Management containers not found"
	@cd $(ANSIBLE_DIR) && ansible reverse_proxy -i $(INVENTORY) -m shell -a "docker ps --format '{{.Names}}' | grep -E '(haproxy|caddy)'" 2>/dev/null | grep -qE "(haproxy|caddy)" && echo "  $(GREEN)✓$(NC) Proxy containers running" || echo "  $(YELLOW)⚠$(NC) Proxy containers not found"
	@echo ""
	@echo "$(CYAN)Configuration:$(NC)"
	@echo "  Domain: $$(grep netbird_domain $(TERRAFORM_DIR)/terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
	@echo "  Proxy: $$(grep proxy_type $(TERRAFORM_DIR)/terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
	@echo "  Database: $$(grep database_type $(TERRAFORM_DIR)/terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"

health:
	@echo "$(BLUE)→ Running health checks...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Not deployed yet$(NC)"; exit 1; }
	@echo ""
	@echo "$(CYAN)Management API:$(NC)"
	@cd $(ANSIBLE_DIR) && ansible management -i $(INVENTORY) -m shell -a "curl -sk https://localhost:443/api/status 2>/dev/null" | grep -q "200" && echo "  $(GREEN)✓$(NC) API responding" || echo "  $(RED)✗$(NC) API not responding"
	@echo ""
	@echo "$(CYAN)Database:$(NC)"
	@grep -q "postgresql" $(TERRAFORM_DIR)/terraform.tfvars && \
		cd $(ANSIBLE_DIR) && ansible management -i $(INVENTORY) -m shell -a "docker exec netbird-management pg_isready -h \$$DB_HOST -U \$$DB_USER 2>/dev/null" | grep -q "accepting" && echo "  $(GREEN)✓$(NC) PostgreSQL connected" || echo "  $(YELLOW)⚠$(NC) PostgreSQL check failed" || \
		echo "  $(CYAN)ℹ$(NC) Using SQLite"
	@echo ""
	@echo "$(CYAN)Proxy:$(NC)"
	@DOMAIN=$$(grep netbird_domain $(TERRAFORM_DIR)/terraform.tfvars | cut -d'=' -f2 | tr -d ' \"') && \
		curl -sk -o /dev/null -w "%{http_code}" https://$$DOMAIN 2>/dev/null | grep -q "200" && echo "  $(GREEN)✓$(NC) HTTPS accessible" || echo "  $(RED)✗$(NC) HTTPS not accessible"

# ═══════════════════════════════════════════════════════════════
# MAINTENANCE
# ═══════════════════════════════════════════════════════════════

backup:
	@echo "$(BLUE)→ Creating backup...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Not deployed yet$(NC)"; exit 1; }
	@mkdir -p backups/$$(date +%Y%m%d)
	@cp -r $(TERRAFORM_DIR)/terraform.tfstate* backups/$$(date +%Y%m%d)/ 2>/dev/null || true
	@cp $(TERRAFORM_DIR)/terraform.tfvars backups/$$(date +%Y%m%d)/ 2>/dev/null || true
	@cp $(INVENTORY) backups/$$(date +%Y%m%d)/ 2>/dev/null || true
	@echo "$(GREEN)✓ Backup created in backups/$$(date +%Y%m%d)$(NC)"

upgrade:
	@echo "$(BLUE)→ Upgrading NetBird...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Not deployed yet$(NC)"; exit 1; }
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/upgrade.yml
	@echo "$(GREEN)✓ Upgrade complete$(NC)"

rollback:
	@echo "$(YELLOW)→ Rolling back to previous version...$(NC)"
	@test -f $(INVENTORY) || { echo "$(RED)✗ Not deployed yet$(NC)"; exit 1; }
	@echo "$(RED)⚠ This will restart all services$(NC)"
	@read -p "Continue? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/site.yml --tags rollback
	@echo "$(GREEN)✓ Rollback complete$(NC)"

# ═══════════════════════════════════════════════════════════════
# CLEANUP & DESTROY
# ═══════════════════════════════════════════════════════════════

clean:
	@echo "$(BLUE)→ Cleaning temporary files...$(NC)"
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -f $(TERRAFORM_DIR)/tfplan*
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate.backup
	@find . -type f -name "*.retry" -delete
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

destroy:
	@echo "$(RED)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(RED)  ⚠ WARNING: DESTRUCTIVE OPERATION$(NC)"
	@echo "$(RED)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "This will destroy:"
	@echo "  • All NetBird containers and services"
	@echo "  • All Terraform-managed infrastructure"
	@echo "  • Generated inventory files"
	@echo ""
	@echo "This will NOT destroy:"
	@echo "  • External PostgreSQL database"
	@echo "  • External Keycloak instance"
	@echo "  • DNS records"
	@echo ""
	@read -p "Type 'destroy' to confirm: " confirm && [ "$$confirm" = "destroy" ] || { echo "$(YELLOW)Cancelled$(NC)"; exit 1; }
	@echo ""
	@echo "$(BLUE)→ Running Ansible cleanup...$(NC)"
	@test -f $(INVENTORY) && cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/cleanup.yml || echo "$(YELLOW)⚠ Inventory not found, skipping Ansible cleanup$(NC)"
	@echo "$(BLUE)→ Destroying Terraform infrastructure...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform destroy
	@$(MAKE) clean
	@echo "$(GREEN)✓ Destruction complete$(NC)"

# ═══════════════════════════════════════════════════════════════
# DEVELOPMENT HELPERS
# ═══════════════════════════════════════════════════════════════

.PHONY: dev-setup dev-validate dev-deploy
dev-setup: check-tools init validate-config
	@echo "$(GREEN)✓ Development environment ready$(NC)"

dev-validate: fmt test lint
	@echo "$(GREEN)✓ All validations passed$(NC)"

dev-deploy: dev-validate plan
	@echo "$(CYAN)Ready to deploy. Run: make apply$(NC)"
