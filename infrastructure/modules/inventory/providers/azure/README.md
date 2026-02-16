# Azure Inventory Module

Discovers existing Azure Virtual Machines based on tags for NetBird deployment.

## Overview

This module uses Azure data sources to discover running Virtual Machines matching specific tags within a resource group. It returns a normalized list of instances with their network configuration for use in Ansible inventory generation.

## Usage

```hcl
module "inventory_azure" {
  source = "./modules/inventory-azure"
  
  resource_group_name = "netbird-prod-rg"
  
  tag_filters = {
    "Project"     = "netbird"
    "Environment" = "prod"
    "Role"        = "*"  # Discovers instances with any role
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `resource_group_name` | Azure resource group name | `string` | - | Yes |
| `tag_filters` | Tags to filter instances | `map(string)` | `{}` | No |

### Tag Filters

The module discovers instances based on Azure tags. Common patterns:

```hcl
# Exact match
tag_filters = {
  "Project" = "netbird"
  "Role"    = "management"
}

# Wildcard (any value)
tag_filters = {
  "Project" = "netbird"
  "Role"    = "*"  # Any role: management, relay, reverse-proxy
}
```

### Required Instance Tags

Instances MUST have these tags to be discovered:
- Tags matching `tag_filters` configuration
- **Role**: Must be one of `management`, `relay`, or `reverse-proxy`

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `instances` | List of discovered instances | `list(object)` |

### Instance Object Structure

Each instance in the `instances` output contains:

```hcl
{
  name       = "netbird-management-1"
  public_ip  = "20.1.2.3"
  private_ip = "10.0.1.10"
  role       = "management"  # from Role tag
}
```

## Instance State Filter

The module only discovers instances in **running** (PowerState/running) state. Stopped or deallocated instances are automatically excluded.

## Example: Multi-Role Discovery

```hcl
module "inventory_azure" {
  source = "./modules/inventory-azure"
  
  resource_group_name = "netbird-prod-rg"
  
  # Discover all NetBird instances regardless of role
  tag_filters = {
    "Project" = "netbird"
  }
}
```

## Resource Group Scope

The module only discovers VMs within the specified `resource_group_name`. VMs in other resource groups are not included, even if they match the tag filters.

## Related Documentation

- [Getting Started Guide](../../../../ansible-stack/docs/getting-started.md)
- [Configuration Reference](../../../../ansible-stack/docs/configuration-reference.md)
- [Architecture Overview](../../../../../docs/architecture.md)
