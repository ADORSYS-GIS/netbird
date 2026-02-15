# Infrastructure as Code (IaC)

This directory contains the Terraform modules and environment definitions for provisioning the underlying infrastructure.

## Structure
- `modules/`: Reusable Terraform modules (`k8s-stack`, `docker-stack`, `data-store`).
- `environments/`: Environment-specific instantiations (`prod`, `staging`).
  - Each environment should contain a `main.tf` calling the modules.
