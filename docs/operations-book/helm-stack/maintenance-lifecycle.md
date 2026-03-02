# 📘 03 | Maintenance Lifecycle

**Standard Operating Procedures (SOPs)**

[[_TOC_]]

---

## Maintenance Lifecycle SOPs

- **Terraform Updates**: Plan first, apply only if clean. Use remote backend for state.
- **Helm Releases**: Use `atomic = false`, `cleanup_on_fail = true`, and `wait = true` for safe rollouts.
- **Database Backups**: Automated daily snapshots at 04:00 (retained for 7 days) via Cloud SQL configuration.
- **Secret Rotation**: Rotate `idp_client_secret` and `datastore_encryption_key` using a coordinated maintenance window.
- **TLS Renewal**: Automated via Cert-Manager and Let's Encrypt (ClusterIssuer).

---
*Last Updated: 2026-02-27*
