# 📘 03 | Maintenance Lifecycle (Ansible Stack)

**Standard Operating Procedures (SOPs)**

[[_TOC_]]

---

## Maintenance Lifecycle SOPs

- **Infrastructure Provisioning**: Terraform plan/apply with automated Ansible triggers.
- **Rolling Upgrades**: Blue-green or rolling updates via specialized Ansible playbooks.
- **Certificate Renewal**: Automated every 60 days via `acme.sh` integration in HAProxy.
- **Security Validation**: Weekly automated scans via `validate-security.yml`.

---
*Last Updated: 2026-02-27*
