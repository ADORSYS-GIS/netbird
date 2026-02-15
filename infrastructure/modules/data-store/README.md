# Data Store Module

This Terraform module (`data-store`) provisions a **High Availability** database layer for NetBird.

## Supported Engines
- **Cloud Managed:** RDS, CloudSQL, Azure SQL (Recommended).
- **Self-Hosted:** HA PostgreSQL Cluster (Patroni/Spilo) on K8s or VMs.

## Usage
```hcl
module "netbird_db" {
  source = "../../modules/data-store"

  engine_version = "14"
  ha_enabled     = true
  # ... other variables
}
```
