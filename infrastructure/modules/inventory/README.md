# Inventory Module

Transforms host definitions into Ansible inventory structure.

## Usage

```hcl
module "inventory" {
  source = "../modules/inventory"

  netbird_hosts = {
    management-1 = {
      public_ip  = "203.0.113.10"
      private_ip = "10.0.1.10"
      roles      = ["management"]
      ssh_user   = "ubuntu"
    }
    proxy-1 = {
      public_ip  = "203.0.113.20"
      private_ip = "10.0.2.10"
      roles      = ["proxy"]
    }
  }
}
```

## Outputs

- `management_nodes` - Hosts with management role
- `reverse_proxy_nodes` - Hosts with proxy role
- `relay_nodes` - Hosts with relay role
- `all_instances` - All defined hosts
