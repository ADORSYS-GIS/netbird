# Maintenance Lifecycle (Helm Stack)

**Standard Operating Procedures (SOPs)**

## Maintenance Operations

<details open>
<summary>Routine Maintenance Tasks</summary>

### Terraform Updates
- **Method**: Plan first, apply only if clean
- **State Management**: Use remote backend for state
- **Frequency**: As needed for infrastructure changes
- **Best Practice**: Always review plan output before applying

### Helm Releases
- **Configuration**: Use `atomic = false`, `cleanup_on_fail = true`, and `wait = true`
- **Purpose**: Safe rollouts with automatic cleanup
- **Frequency**: On version releases
- **Rollback**: Automated via Helm history

### Database Backups
- **Method**: Automated daily snapshots via Cloud SQL configuration
- **Schedule**: Daily at 04:00 UTC
- **Retention**: 7 days
- **Verification**: Weekly restore tests recommended

### Secret Rotation
- **Secrets**: `idp_client_secret` and `datastore_encryption_key`
- **Method**: Coordinated maintenance window required
- **Frequency**: Quarterly or as needed
- **Impact**: Brief service restart required

### TLS Certificate Renewal
- **Method**: Automated via Cert-Manager and Let's Encrypt
- **Configuration**: ClusterIssuer
- **Frequency**: Every 90 days (automatic)
- **Monitoring**: Alert on expiration < 30 days

</details>

## Maintenance Schedule

<details>
<summary>Recommended Maintenance Windows</summary>

| Task | Frequency | Duration | Impact |
|------|-----------|----------|--------|
| Helm Upgrades | On release | 15-30 minutes | Rolling update (minimal) |
| Terraform Updates | Monthly | 30-60 minutes | None (plan-based) |
| Secret Rotation | Quarterly | 15 minutes | Brief restart |
| Database Maintenance | Weekly | 5 minutes | None (automated) |
| Certificate Renewal | Every 90 days | Automatic | None |

</details>

## Related Documentation

- [Deployment Runbook](../../runbooks/helm-stack/deployment.md)
- [Upgrade Runbook](../../runbooks/helm-stack/upgrade.md)
- [Architecture Strategy](./architecture-strategy.md)
