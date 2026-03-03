# NetBird Infrastructure Automation

Production-grade automation framework for deploying NetBird on any infrastructure.

## 🚀 Deployment Guide

Choose the deployment method that matches your infrastructure:

### [Option A: VM Deployment (Recommended)](./docs/runbooks/ansible-stack/deployment.md)
Deploy on standard Virtual Machines (AWS EC2, Google Compute Engine, Azure VMs, or On-Prem) using **Terraform** for discovery and **Ansible** for configuration.

*   [**Start VM Deployment**](./docs/runbooks/ansible-stack/deployment.md)
*   [**Infrastructure README**](./infrastructure/ansible-stack/README.md)

### [Option B: Kubernetes Deployment](./docs/runbooks/helm-stack/deployment.md)
Deploy on a Kubernetes cluster using **Terraform** and **Helm**.

*   [**Kubernetes Guide**](./docs/runbooks/helm-stack/deployment.md)

## 📚 Documentation

*   [**Architecture Overview**](./docs/architecture.md)
*   [**Security Hardening**](./docs/operations-book/security-hardening.md)
*   [**Configuration Reference**](./infrastructure/ansible-stack/README.md)
*   [**Troubleshooting**](./docs/runbooks/ansible-stack/troubleshooting-restoration.md)

## Features

-   **Multi-Cloud Discovery**: Automatically discovers existing VMs via tags/labels
-   **Security First**: Private IP binding, UFW firewall, defense-in-depth architecture
-   **Automated Identity**: Terraform configures Keycloak realms and clients
-   **Hybrid Ready**: Supports AWS, GCP, Azure, and manual/on-premises hosts

## Acknowledgments

Built with [NetBird](https://netbird.io) - Open-source VPN management platform.
