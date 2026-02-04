# NetBird Infrastructure

## Overview

Production-grade infrastructure automation for NetBird deployments.

This repository provides comprehensive deployment solutions for NetBird with Caddy setup as reverse proxy.

## Deployment Options

### 1. Automated Deployment (Recommended)

Use Ansible to automatically provision NetBird with Caddy, Keycloak, and all required configurations.

- **Guide**: [Ansible Deployment Guide](infrastructure/ansible/README.md)

### 2. Quickstart (Test/Dev)

Quickly bootstrap a full stack including Zitadel IdP using the setup script.

- **Guide**: [Quickstart with Zitadel](infrastructure/scripts/README.md)

### 3. Manual Deployment

Manually deploy NetBird with Caddy reverse proxy on a single host.

- **Guide**: [Manual Caddy Deployment Guide](docs/caddy-deployment.md)

## Securing Your Applications

Leverage NetBird to secure access to your private applications and services. This guide covers common use cases and provides step-by-step instructions to help you implement robust, zero-trust access controls.

- **Guide**: [Secure Application Access with NetBird](docs/netbird-secure-access-guide.md)

## Support and Contributions

- Documentation: [docs/](docs/)
- Issues: GitHub issue tracker
- NetBird: [Official documentation](https://docs.netbird.io/)
