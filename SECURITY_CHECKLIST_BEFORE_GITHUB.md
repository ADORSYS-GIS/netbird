# 🔐 SECURITY CHECKLIST - BEFORE PUSHING TO GITHUB

## ✅ COMPLETED FIXES

- [x] **Sanitized terraform.tfvars**
  - Removed all database passwords
  - Removed all API secrets and tokens
  - Removed real domain names (replaced with placeholders)
  - Removed all IP addresses (public/private)
  - Removed email addresses
  - Replaced with "CHANGE_ME_*" placeholders

- [x] **Created terraform.tfvars.example**
  - Template for users to configure their own deployment
  - Instructions for generating secrets
  - Comments on environment variable usage
  - Security best practices documented

- [x] **Updated .gitignore**
  - Added comprehensive Terraform secrets exclusion
  - Added Ansible inventory exclusion
  - Added SSH key exclusion
  - Added vault/encrypted data exclusion
  - Organized with clear sections

## ⚠️ CRITICAL FILES TO VERIFY

Before any GitHub push, ensure:

```bash
# 1. Check no secrets in committed files
git diff --cached | grep -i "password\|secret\|token\|apikey"

# 2. Verify terraform.tfvars is not staged
git status | grep terraform.tfvars

# 3. Check for IP addresses
git diff --cached | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"

# 4. Check for email addresses
git diff --cached | grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"

# 5. Check for domain names with real TLD
git diff --cached | grep -E "observe\.camer\.digital|neon\.tech"

# 6. Run gitleaks scan
gitleaks detect --source . --verbose
```

## 📁 FILES STATUS

### ✅ Safe to Commit
- `infrastructure/ansible-stack/terraform.tfvars` (now sanitized)
- `infrastructure/ansible-stack/terraform.tfvars.example`
- `configuration/ansible/**/*.j2` (uses variables, not hardcoded values)
- `configuration/ansible/roles/**/*.yml` (uses variables)
- `.gitignore` (enhanced with security rules)

### ❌ MUST NOT COMMIT
- `configuration/ansible/inventory/terraform_inventory.yaml` (auto-generated with real secrets)
- Any `.env` or `.env.*` files
- Any `*.key`, `*.pem`, `*.vault` files
- Any SSH private keys

## 🔄 ENVIRONMENT VARIABLE APPROACH (RECOMMENDED)

Instead of storing secrets in terraform.tfvars, use environment variables:

```bash
# Before terraform apply:
export TF_VAR_existing_postgresql_password="your-real-password"
export TF_VAR_keycloak_admin_password="your-real-password"
export TF_VAR_netbird_admin_password="your-real-password"
export TF_VAR_relay_auth_secret="$(openssl rand -hex 32)"
export TF_VAR_netbird_encryption_key="$(openssl rand -hex 32)"

# Then run terraform
terraform apply
```

## 🚀 CI/CD BEST PRACTICE

For GitHub Actions or other CI/CD, use GitHub Secrets:

```yaml
# .github/workflows/deploy.yml
env:
  TF_VAR_existing_postgresql_password: ${{ secrets.DB_PASSWORD }}
  TF_VAR_keycloak_admin_password: ${{ secrets.KEYCLOAK_PASSWORD }}
  TF_VAR_netbird_admin_password: ${{ secrets.NETBIRD_PASSWORD }}
  TF_VAR_relay_auth_secret: ${{ secrets.RELAY_SECRET }}
  TF_VAR_netbird_encryption_key: ${{ secrets.ENCRYPTION_KEY }}
```

## 📋 PRE-PUSH COMMANDS

Run these before pushing to GitHub:

```bash
# 1. Check git status
git status

# 2. Verify no secrets in staging area
git diff --cached | grep -iE "password|secret|token|apikey" && echo "⚠️  SECRETS FOUND!" || echo "✓ No obvious secrets"

# 3. Scan with gitleaks
gitleaks detect --source . --exit-code 1 && echo "✓ No secrets detected" || echo "⚠️  Secrets found!"

# 4. Review unstaged changes
git diff | head -100

# 5. Final safety check
git log -1 --name-only --pretty=format: | xargs -I {} test -f {} && file {} | grep -iE "secret|vault|password" && echo "⚠️  Suspicious files" || echo "✓ All clear"
```

## 🔍 WHAT TO LOOK FOR IN CODE REVIEW

When reviewing code before GitHub push:

- [ ] No hardcoded database passwords or connection strings
- [ ] No API keys or tokens in string literals
- [ ] No private SSH keys or certificate files
- [ ] No environment-specific values (IPs, domains, emails)
- [ ] No terraform.tfvars file in staged changes
- [ ] No inventory files with real values
- [ ] All credentials in environment variables or secrets manager
- [ ] `.gitignore` properly configured

## 📚 DOCUMENTATION CREATED

- `SECURITY_AUDIT_REPORT.md` - Full audit findings
- `SECURITY_CHECKLIST_BEFORE_GITHUB.md` - This file
- `infrastructure/ansible-stack/terraform.tfvars.example` - Configuration template

## ✅ FINAL APPROVAL

Before GitHub push, confirm:

```
✓ terraform.tfvars sanitized
✓ terraform.tfvars.example created
✓ .gitignore enhanced
✓ No real secrets in any committed code
✓ No database credentials visible
✓ No API tokens visible
✓ No SSH keys visible
✓ All IPs replaced with placeholders
✓ All domains replaced with placeholders
✓ All emails replaced with placeholders
```

---

**🎯 STATUS**: Ready for GitHub publication after environment variable configuration

