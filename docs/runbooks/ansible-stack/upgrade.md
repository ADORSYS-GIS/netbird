# 📕 UPGRADE-01 | NetBird Ansible Stack Rolling Update
**Action Type**: Upgrade | **Risk**: Medium | **Ops Book**: [Ansible Stack Ops](../../operations-book/ansible-stack/README.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates
<details open>
<summary>Execution Checklist & Quorum</summary>

- [ ] **Backup**: Database snapshots taken?
- [ ] **Release**: Target `netbird_version` set in `terraform.tfvars`?
- [ ] **Health**: Cluster is currently GREEN?

**STOP IF**: `cluster_control -l` shows less than 3 nodes online.

</details>

---

## 02. Step-by-Step Execution
<details open>
<summary>The "Golden Path" Procedure (Rolling Update)</summary>

### STEP 01 - Review Changes
Compare current vs new versions:
```bash
grep netbird_version infrastructure/ansible-stack/terraform.tfvars
# Update version string to desired release
```

### STEP 02 - Perform Rolling Update
The `upgrade.yml` playbook uses `serial: 1` to ensure zero-downtime:
```bash
cd configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/upgrade.yml --tags upgrade
```

### STEP 03 - Verify Node Health
Monitor each node as it restarts:
```bash
# Watch health check endpoint
watch -n 1 'curl -f http://localhost:9000'
```

</details>

---

## 03. Verification & Acceptance
<details>
<summary>Post-Upgrade Hardening</summary>

| Component | Check | Pass Criteria |
| :--- | :--- | :--- |
| **Management** | Version Check | Matches `netbird_version` |
| **Cluster** | Sync Status | All Nodes Connected |
| **Dashboard** | Web UI Access | 200 OK |

</details>

---

## 04. Emergency Rollback (The Panic Button)
<details>
<summary>Rollback Instructions</summary>

**Trigger**: [Trigger, e.g., Version incompatibility or Agent sync loss]

```bash
# Revert to previous version in tfvars
git checkout infrastructure/ansible-stack/terraform.tfvars

# Re-run upgrade playbook with previous stable version
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/upgrade.yml --tags upgrade
```

</details>

---

## Appendix
<details>
<summary>Metadata & Revision History</summary>

| Date | Version | Author | Reviewer | Changes |
| :--- | :--- | :--- | :--- | :--- |
| 2026-02 | 1.0 | Zencoder Agent | Platform Team | Initial Upgrade Runbook |

</details>
