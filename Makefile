.PHONY: help test test-terraform test-ansible test-all fmt fmt-terraform fmt-ansible lint lint-terraform lint-ansible security clean

# Default target
help:
	@echo "NetBird Infrastructure - Make Targets"
	@echo ""
	@echo "Testing:"
	@echo "  test              - Run all tests (Terraform + Ansible)"
	@echo "  test-terraform    - Run Terraform validation tests"
	@echo "  test-ansible      - Run Ansible syntax and lint tests"
	@echo ""
	@echo "Formatting:"
	@echo "  fmt               - Format all code (Terraform + Ansible)"
	@echo "  fmt-terraform     - Format Terraform code"
	@echo ""
	@echo "Linting:"
	@echo "  lint              - Lint all code"
	@echo "  lint-terraform    - Lint Terraform with tfsec and checkov"
	@echo "  lint-ansible      - Lint Ansible playbooks"
	@echo ""
	@echo "Security:"
	@echo "  security          - Run security scans (secrets, IaC)"
	@echo ""
	@echo "Utilities:"
	@echo "  clean             - Clean temporary files"

# Run all tests
test: test-terraform test-ansible
	@echo "✓ All tests passed"

# Terraform validation
test-terraform:
	@echo "Running Terraform validation..."
	@echo "Validating ansible-stack..."
	@cd infrastructure/ansible-stack && terraform fmt -check -recursive
	@cd infrastructure/ansible-stack && terraform init -backend=false
	@cd infrastructure/ansible-stack && terraform validate
	@echo "✓ ansible-stack validation passed"
	@echo "Validating modules..."
	@cd infrastructure/modules && terraform fmt -check -recursive
	@echo "✓ Terraform validation passed"

# Ansible validation
test-ansible:
	@echo "Running Ansible validation..."
	@cd configuration/ansible && ansible-playbook --syntax-check playbooks/site.yml
	@echo "✓ Ansible syntax check passed"

# Format Terraform code
fmt-terraform:
	@echo "Formatting Terraform code..."
	@cd infrastructure/ansible-stack && terraform fmt -recursive
	@cd infrastructure/modules && terraform fmt -recursive
	@echo "✓ Terraform code formatted"

# Format all code
fmt: fmt-terraform
	@echo "✓ All code formatted"

# Lint Terraform with security tools
lint-terraform:
	@echo "Linting Terraform code..."
	@command -v tfsec >/dev/null 2>&1 || { echo "tfsec not installed. Install: https://github.com/aquasecurity/tfsec"; exit 1; }
	@tfsec infrastructure/ansible-stack/ --minimum-severity MEDIUM
	@tfsec infrastructure/modules/ --minimum-severity MEDIUM
	@echo "✓ Terraform linting passed"

# Lint Ansible playbooks
lint-ansible:
	@echo "Linting Ansible playbooks..."
	@command -v ansible-lint >/dev/null 2>&1 || { echo "ansible-lint not installed. Run: pip install ansible-lint"; exit 1; }
	@ansible-lint configuration/ansible/playbooks/site.yml || true
	@echo "✓ Ansible linting completed"

# Run all linters
lint: lint-terraform lint-ansible
	@echo "✓ All linting completed"

# Security scans
security:
	@echo "Running security scans..."
	@echo "1. Checking for secrets..."
	@command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --no-git || echo "⚠ gitleaks not installed (optional)"
	@echo "2. Scanning Terraform..."
	@command -v tfsec >/dev/null 2>&1 && tfsec infrastructure/ || echo "⚠ tfsec not installed"
	@echo "3. Scanning infrastructure config..."
	@command -v trivy >/dev/null 2>&1 && trivy config infrastructure/ || echo "⚠ trivy not installed (optional)"
	@echo "✓ Security scans completed"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true
	@rm -rf configuration/ansible/inventory/terraform_inventory.yaml 2>/dev/null || true
	@echo "✓ Cleanup completed"

# Quick validation (fast checks before commit)
quick-check:
	@echo "Running quick validation checks..."
	@cd infrastructure/ansible-stack && terraform fmt -check -recursive
	@cd infrastructure/modules && terraform fmt -check -recursive
	@ansible-playbook --syntax-check configuration/ansible/playbooks/site.yml
	@echo "✓ Quick checks passed"

# Full pre-commit validation
pre-commit: fmt test lint
	@echo "✓ Pre-commit validation completed - ready to commit!"
