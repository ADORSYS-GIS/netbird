# Manual Inventory Module

Provides manual/on-premises host configuration for NetBird deployment without cloud provider discovery.

## Overview

This module allows you to manually specify hosts (on-premises servers, bare metal, or cloud VMs not discoverable via tags/labels). Useful for:
- **On-premises deployments**
- **Bare metal servers**
- **Hybrid cloud** (mixing cloud-discovered + manual hosts)
- **Testing/development** with specific IPs

## Usage

```hcl
module "inventory_manual" {
  source = "./modules/inventory-manual"
  
  manual_hosts = [
    {
      name       = "netbird-mgmt-onprem"
      public_ip  = "203.0.113.10"
      private_ip = "192.168.1.10"
      role       = "management"
    },
    {
      name       = "netbird-relay-onprem"
      public_ip  = "203.0.113.11"
      private_ip = "192.168.1.11"
      role       = "relay"
    },
    {
      name       = "netbird-proxy-onprem"
      public_ip  = "203.0.113.12"
      private_ip = "192.168.1.12"
      role       = "reverse-proxy"
    }
  ]
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `manual_hosts` | List of manual host configurations | `list(object)` | `[]` | No |

### Manual Hosts Object Structure

Each host in `manual_hosts` must contain:

| Field | Description | Type | Required | Example |
|-------|-------------|------|----------|---------|
| `name` | Unique host identifier | `string` | Yes | `netbird-mgmt-1` |
| `public_ip` | Public IP address | `string` | No* | `203.0.113.10` |
| `private_ip` | Private IP address | `string` | Yes | `192.168.1.10` |
| `role` | NetBird role | `string` | Yes | `management`, `relay`, `reverse-proxy` |

\* **public_ip** can be empty string (`""`) for fully private deployments.

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `instances` | List of manual instances | `list(object)` |

## Examples

### On-Premises Deployment

```hcl
module "inventory_manual" {
  source = "./modules/inventory-manual"
  
  manual_hosts = [
    {
      name       = "mgmt-server-dc1"
      public_ip  = ""  # No public IP (private network only)
      private_ip = "10.0.0.5"
      role       = "management"
    }
  ]
}
```

### Hybrid Deployment (Cloud + On-Premises)

```hcl
# Cloud instances (auto-discovered)
module "inventory_aws" {
  source      = "./modules/inventory-aws"
  region      = "us-east-1"
  tag_filters = { "Project" = "netbird" }
}

# On-premises instances (manual)
module "inventory_manual" {
  source = "./modules/inventory-manual"
  
  manual_hosts = [
    {
      name       = "netbird-mgmt-datacenter"
      public_ip  = ""
      private_ip = "192.168.10.50"
      role       = "management"
    }
  ]
}

# Combine both in main.tf
locals {
  all_instances = concat(
    module.inventory_aws.instances,
    module.inventory_manual.instances
  )
}
```

### Testing with Localhost

```hcl
module "inventory_manual" {
  source = "./modules/inventory-manual"
  
  manual_hosts = [
    {
      name       = "localhost-test"
      public_ip  = "127.0.0.1"
      private_ip = "127.0.0.1"
      role       = "management"
    }
  ]
}
```

## Validation

The module validates:
- ✅ `role` must be one of: `management`, `relay`, `reverse-proxy`
- ✅ All required fields (`name`, `private_ip`, `role`) are provided
- ❌ Duplicate `name` values will cause Terraform errors

## Related Documentation

- [Getting Started Guide](../../../ansible-stack/docs/getting-started.md)
- [Configuration Reference](../../../ansible-stack/docs/configuration-reference.md)
- [Architecture Overview](../../../../../../../../docs/architecture.md)
