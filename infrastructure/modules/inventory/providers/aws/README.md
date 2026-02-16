# AWS Inventory Module

Discovers existing EC2 instances in AWS based on tags for NetBird deployment.

## Overview

This module uses AWS data sources to discover running EC2 instances matching specific tags. It returns a normalized list of instances with their network configuration for use in Ansible inventory generation.

## Usage

```hcl
module "inventory_aws" {
  source = "./modules/inventory-aws"
  
  region = "us-east-1"
  
  tag_filters = {
    "Project"     = "netbird"
    "Environment" = "prod"
    "Role"        = "*"  # Discovers instances with any role
  }
  
  environment = "prod"
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `region` | AWS region | `string` | `us-east-1` | No |
| `tag_filters` | Tags to filter instances | `map(string)` | `{}` | No |
| `environment` | Environment name | `string` | - | Yes |

### Tag Filters

The module discovers instances based on EC2 tags. Common patterns:

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
| `vpc_id` | VPC ID of discovered instances | `string` |
| `subnet_ids` | List of subnet IDs | `list(string)` |

### Instance Object Structure

Each instance in the `instances` output contains:

```hcl
{
  name       = "netbird-management-1"
  public_ip  = "52.1.2.3"
  private_ip = "10.0.1.10"
  role       = "management"  # from Role tag
}
```

## Instance State Filter

The module only discovers instances in **running** state. Stopped or terminated instances are automatically excluded.

## Example: Multi-Role Discovery

```hcl
module "inventory_aws" {
  source = "./modules/inventory-aws"
  
  region = "us-east-1"
  
  # Discover all NetBird instances regardless of role
  tag_filters = {
    "Project" = "netbird"
  }
  
  environment = "prod"
}

# Results in:
# instances = [
#   { name = "mgmt-1", role = "management", ... },
#   { name = "relay-1", role = "relay", ... },
#   { name = "proxy-1", role = "reverse-proxy", ... }
# ]
```

## Network Information

The module extracts VPC and subnet information from discovered instances, useful for database deployment:

```hcl
module "database" {
  source = "./modules/database-backend"
  
  # Use VPC from discovered instances
  vpc_id              = module.inventory_aws.vpc_id
  database_subnet_ids = module.inventory_aws.subnet_ids
  
  # ... other database configuration
}
```

## Related Documentation

- [Getting Started Guide](../../../ansible-stack/docs/getting-started.md)
- [Configuration Reference](../../../ansible-stack/docs/configuration-reference.md)
- [Architecture Overview](../../../../../../../../docs/architecture.md)
