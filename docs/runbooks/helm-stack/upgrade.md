# 📕 U01 | NetBird Infrastructure Upgrade

**Action Type**: Upgrade | **Risk**: Medium | **Ops Book**: [./operations-book.md](../operations-book.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Backup Verified**: Database snapshots (Cloud SQL) and Terraform state are backed up.
- [ ] **Changelog Reviewed**: [NetBird Releases](https://github.com/netbirdio/netbird/releases) checked for breaking changes.
- [ ] **Metrics Stable**: Cluster health is green, and there are no active P1/P2 incidents.
- [ ] **Staging Tested**: The target version has been successfully deployed in a non-production environment.

**STOP IF**: The current error rate is > 0.5% or if a critical database backup is missing.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Update Version Configuration

```bash
# Navigate to the terraform directory
cd infrastructure/helm-stack/terraform
```

**Edit `terraform.tfvars`**: Update `netbird_chart_version` to the target version (e.g., `1.10.0`).

### STEP 02 - Perform Dry-Run

```bash
# Generate and review the upgrade plan
terraform plan -out=upgrade.tfplan
```
Verify that only the Helm release version and associated metadata are changing.

### STEP 03 - Apply Upgrade

```bash
# Apply the upgrade plan
terraform apply "upgrade.tfplan"
```

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Helm Rollout Status

```bash
# Verify the Helm release history
helm history netbird -n netbird

# Check pod rollout status
kubectl rollout status deployment/netbird-management -n netbird
kubectl rollout status deployment/netbird-signal -n netbird
```

### V02 - System Health

```bash
# Ensure all pods are Running and Ready
kubectl get pods -n netbird
```

### V03 - Connectivity Test
Connect a test peer to the network and verify it can reach the Management API and other peers.

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### R01 - Terraform Reversion
1. Revert the `netbird_chart_version` in `terraform.tfvars` to the previous known-good version.
2. Run `terraform apply -auto-approve`.

### R02 - Emergency Helm Rollback
If Terraform is stuck or failing:
```bash
# Rollback to the previous revision
helm rollback netbird $(helm history netbird -n netbird --max 2 | awk 'NR==2 {print $1}') -n netbird

# Reconcile Terraform state afterward
terraform refresh
```

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
