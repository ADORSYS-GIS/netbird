# NetBird Kubernetes Stack Module

This Terraform module (`k8s-stack`) is designed to deploy a **High Availability** NetBird cluster on Kubernetes.

## Features
- Wraps the official NetBird Helm chart.
- Configures external database connections (optional but recommended for HA).
- Sets up Ingress/Certificate resources.

## Usage
```hcl
module "netbird_k8s" {
  source = "../../modules/k8s-stack"

  domain = "netbird.example.com"
  # ... other variables
}
```
