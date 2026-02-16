# GCP Inventory Module

Discovers existing GCP Compute Engine instances based on labels for NetBird deployment.

## Overview

This module uses GCP data sources to discover running Compute Engine instances matching specific labels. It returns a normalized list of instances with their network configuration for use in Ansible inventory generation.

## Usage

```hcl
module "inventory_gcp" {
  source = "./modules/inventory-gcp"
  
  project = "my-gcp-project"
  region  = "us-central1"
  
  label_filters = {
    "project"     = "netbird"
    "environment" = "prod"
    "role"        = "*"  # Discovers instances with any role
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project` | GCP project ID | `string` | - | Yes |
| `region` | GCP region | `string` | `us-central1` | No |
| `label_filters` | Labels to filter instances | `map(string)` | `{}` | No |

### Label Filters

The module discovers instances based on GCP labels. Common patterns:

```hcl
# Exact match
label_filters = {
  "project" = "netbird"
  "role"    = "management"
}

# Wildcard (any value)
label_filters = {
  "project" = "netbird"
  "role"    = "*"  # Any role: management, relay, reverse-proxy
}
```

### Required Instance Labels

Instances MUST have these labels to be discovered:
- Labels matching `label_filters` configuration
- **role**: Must be one of `management`, `relay`, or `reverse-proxy`

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `instances` | List of discovered instances | `list(object)` |

### Instance Object Structure

Each instance in the `instances` output contains:

```hcl
{
  name       = "netbird-management-1"
  public_ip  = "34.1.2.3"
  private_ip = "10.128.0.2"
  role       = "management"  # from role label
}
```

## Instance State Filter

The module only discovers instances in **RUNNING** state. Stopped or terminated instances are automatically excluded.

## Example: Multi-Role Discovery

```hcl
module "inventory_gcp" {
  source = "./modules/inventory-gcp"
  
  project = "my-gcp-project"
  region  = "us-central1"
  
  # Discover all NetBird instances regardless of role
  label_filters = {
    "project" = "netbird"
  }
}
```

## Related Documentation

- [Getting Started Guide](../../../ansible-stack/docs/getting-started.md)
- [Configuration Reference](../../../ansible-stack/docs/configuration-reference.md)
- [Architecture Overview](../../../../../../../../docs/architecture.md)
