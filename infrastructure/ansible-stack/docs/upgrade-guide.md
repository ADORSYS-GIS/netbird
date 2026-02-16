# Upgrade Guide

Procedures for upgrading NetBird and infrastructure components.

## Version Compatibility Matrix

| Component | Minimum Version | Recommended Version |
| :--- | :--- | :--- |
| **NetBird** | 0.28.0 | Latest Stable |
| **Caddy** | 2.6.0 | Latest Stable |
| **PostgreSQL** | 13 | 14+ |

## Pre-Upgrade Checklist
1.  [ ] Backup Database (See [Disaster Recovery](../../../docs/operations/disaster-recovery.md)).
2.  [ ] Verify current cluster health (`validate-security.yml`).
3.  [ ] Check NetBird release notes for breaking changes.

## Upgrade Procedures

### Minor Version Upgrade (e.g., 0.29.1 → 0.29.5)

1.  **Update Terraform Variable**:
    Edit `infrastructure/terraform.tfvars`:
    ```hcl
    netbird_version = "0.29.5"
    ```

2.  **Apply Terraform**:
    This updates the inventory/variables but *does not* redeploy yet.
    ```bash
    cd infrastructure
    terraform apply
    ```

3.  **Run Ansible Update**:
    This pulls the new Docker images and restarts containers.
    ```bash
    cd ../configuration
    ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
    ```

### Rolling Upgrade (Zero Downtime)
Since we have a Reverse Proxy and multiple Management nodes (if HA is provisioned):

1.  Ansible by default updates hosts in parallel. To do rolling update, edit `playbooks/site.yml` to set `serial: 1` for the management group.
2.  Run the playbook. Ansible will update one node, restart it, wait for it to be healthy, then move to the next.
3.  Caddy will automatically route traffic to the remaining healthy nodes.

## Rollback Procedures

If an upgrade fails:
1.  Revert `netbird_version` in `terraform.tfvars` to the previous version.
2.  Run `terraform apply`.
3.  Run `ansible-playbook playbooks/site.yml`.
4.  (If needed) Restore Database from backup.

## Related Documentation
- [Disaster Recovery](../../../docs/operations/disaster-recovery.md)
- [Troubleshooting](./troubleshooting.md)
