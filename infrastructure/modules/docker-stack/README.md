# NetBird Docker Stack Module

This Terraform module (`docker-stack`) provisions the verification infrastructure for a **Docker-based** NetBird deployment.

## Features
- Provisions Virtual Machines / Compute Instances.
- Sets up Load Balancers for HA.
- Configures Security Groups / Firewalls.

## Usage
```hcl
module "netbird_docker" {
  source = "../../modules/docker-stack"

  instance_count = 3
  # ... other variables
}
```
