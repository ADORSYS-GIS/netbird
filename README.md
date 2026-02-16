# NetBird Infrastructure Automation

Production-grade automation framework for deploying NetBird on any infrastructure.

## 🚀 Deployment Guide

Choose the deployment method that matches your infrastructure:

### [Option A: VM Deployment (Recommended)](./infrastructure/ansible-stack/docs/getting-started.md)
Deploy on standard Virtual Machines (AWS EC2, Google Compute Engine, Azure VMs, or On-Prem) using **Terraform** for discovery and **Ansible** for configuration.

*   [**Start VM Deployment**](./infrastructure/ansible-stack/docs/getting-started.md)
*   [**AWS Guide**](./infrastructure/ansible-stack/docs/aws.md)
*   [**GCP Guide**](./infrastructure/ansible-stack/docs/google-cloud.md)
*   [**Azure Guide**](./infrastructure/ansible-stack/docs/azure.md)

### [Option B: Kubernetes Deployment](./infrastructure/helm-stack/docs/README.md)
Deploy on a Kubernetes cluster using **Terraform** and **Helm**.

*   [**Kubernetes Guide**](./infrastructure/helm-stack/docs/README.md) *(Coming Soon)*

## 📚 Documentation

*   [**Architecture Overview**](./docs/architecture.md)
*   [**Security Hardening**](./docs/operations/security-hardening.md)
*   [**Configuration Reference**](./infrastructure/ansible-stack/docs/configuration-reference.md)
*   [**Troubleshooting**](./infrastructure/ansible-stack/docs/troubleshooting.md)

## Features

-   **Multi-Cloud Discovery**: Automatically discovers existing VMs via tags/labels
-   **Security First**: Private IP binding, UFW firewall, defense-in-depth architecture
-   **Automated Identity**: Terraform configures Keycloak realms and clients
-   **Hybrid Ready**: Supports AWS, GCP, Azure, and manual/on-premises hosts

## Acknowledgments

Built with [NetBird](https://netbird.io) - Open-source VPN management platform.
