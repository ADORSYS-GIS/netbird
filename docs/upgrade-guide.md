# Upgrade Guide

How to upgrade NetBird and infrastructure components managed by this Terraform deployment.

---

## Upgrading NetBird Chart Version

1. **Check the latest version** on [Artifact Hub](https://artifacthub.io/packages/helm/netbird/netbird)

2. **Update the variable** in `terraform.tfvars`:
   ```hcl
   netbird_chart_version = "1.10.0"  # new version
   ```

3. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

4. **Verify**:
   ```bash
   kubectl get pods -n netbird
   helm list -n netbird
   ```

### Breaking Changes Checklist

Before upgrading, check the [NetBird changelog](https://github.com/netbirdio/netbird/releases):
- [ ] Any new required environment variables?
- [ ] Database migration needed?
- [ ] API breaking changes?
- [ ] New ingress annotations required?

---

## Upgrading cert-manager

1. Check [cert-manager releases](https://github.com/cert-manager/cert-manager/releases)
2. Update in `terraform.tfvars`:
   ```hcl
   # Only if install_cert_manager = true
   # Update the version in helm_netbird.tf or add a variable
   ```
3. `terraform apply`
4. Verify: `kubectl get pods -n cert-manager`

> **Note**: cert-manager upgrades may require CRD updates. The Helm chart handles this when `installCRDs = true`.

---

## Upgrading ingress-nginx

1. Check [ingress-nginx releases](https://github.com/kubernetes/ingress-nginx/releases)
2. Update the version in `helm_netbird.tf`
3. `terraform apply`
4. Verify: `kubectl get pods -n ingress-nginx`

---

## Rolling Back

### Via Terraform
```bash
# Revert the version change in terraform.tfvars
terraform apply
```

### Via Helm (emergency)
```bash
helm history netbird -n netbird
helm rollback netbird <REVISION> -n netbird
```

> **Warning**: After a Helm rollback, Terraform state will be out of sync. Run `terraform refresh` to reconcile.

---

## Pre-Upgrade Backup

### Database (PostgreSQL / Cloud SQL)
```bash
# If using Cloud SQL, create a backup
gcloud sql backups create --instance=<instance-name>

# Or via pg_dump
pg_dump -h <host> -U netbird_admin -d netbird > netbird_backup_$(date +%Y%m%d).sql
```

### Terraform State
```bash
# If using GCS backend, state is versioned automatically
# For local state, make a copy
cp terraform.tfstate terraform.tfstate.backup
```

### Keycloak Export
Export the realm from Keycloak Admin Console → Realm Settings → Partial Export.

---

## Keycloak Provider Migration

If migrating from `mrparkers/keycloak` to the official `keycloak/keycloak` provider:

```bash
terraform state replace-provider mrparkers/keycloak keycloak/keycloak
terraform init -upgrade
terraform plan  # should show no changes
```
