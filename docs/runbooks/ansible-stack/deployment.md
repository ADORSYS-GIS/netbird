# 📕 DEPLOY-01 | NetBird Ansible Stack Deployment
**Action Type**: Deployment | **Risk**: Medium | **Ops Book**: [Ansible Stack Ops](../../operations-book/ansible-stack/README.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates
<details open>
<summary>Execution Checklist & Quorum</summary>

- [ ] **Infrastructure Provisioned**: Terraform `apply` successful?
- [ ] **Inventory Verified**: `terraform_inventory.yaml` exists and hosts are reachable?
- [ ] **SSH Keys**: Specified private key path is correct and accessible?
- [ ] **Admin Credentials**: OIDC and DB passwords set in `terraform.tfvars`?

**STOP IF**: `ansible all -m ping` fails for any node.

</details>

---

## 02. Step-by-Step Execution
<details open>
<summary>The "Golden Path" Procedure</summary>

### STEP 01 - Infrastructure Provisioning
```bash
cd infrastructure/ansible-stack
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### STEP 02 - Automated Ansible Orchestration
**Terraform will automatically trigger Ansible.** If a manual run is needed:
```bash
cd configuration/ansible
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
```

### STEP 03 - Post-Deployment Validation
```bash
# Run the automated validation playbook
ansible-playbook -i inventory/terraform_inventory.yaml playbooks/validate-security.yml
```

**Expected Result**: All security tasks passed with no critical failures.

</details>

---

## 03. Verification & Acceptance
<details>
<summary>Post-Action Hardening</summary>

| Component | Check | Pass Criteria |
| :--- | :--- | :--- |
| **API** | `curl -f https://[domain]/health` | HTTP 200 OK |
| **Cluster** | `cluster_control -l` | 3 Connected Nodes |
| **Firewall** | `ufw status` | Port 443 Open |
| **VIP** | `Keepalived Status` | Master active on Primary |

</details>

---

## 04. Emergency Rollback (The Panic Button)
<details>
<summary>Rollback Instructions</summary>

**Trigger**: [Trigger, e.g., VIP inaccessible or DB connection failure]

```bash
# Cleanup infrastructure
cd infrastructure/ansible-stack
terraform destroy -auto-approve

# Restore from previous known state
git checkout [PREVIOUS_STABLE_COMMIT]
terraform apply -auto-approve
```

</details>

---

## Appendix
<details>
<summary>Metadata & Revision History</summary>

| Date | Version | Author | Reviewer | Changes |
| :--- | :--- | :--- | :--- | :--- |
| 2026-02 | 1.0 | Zencoder Agent | Platform Team | Initial Deployment Runbook |

</details>
