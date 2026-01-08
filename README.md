# NetBird Infrastructure

## Overview

Production-grade infrastructure automation for NetBird deployments.

This repository provides comprehensive deployment solutions for NetBird with Caddy setup as reverse proxy.

## NetBird Deployment

You have two options for deploying the NetBird infrastructure.

### Option 1: Automated Deployment (Recommended)

Use Ansible to automatically provision NetBird with Caddy, Keycloak, and all required configurations.

- **Guide**: [Ansible Deployment Guide](ansible-automation/README.md)

### Option 2: Manual Deployment

 Manually deploy NetBird with Caddy reverse proxy on a single host.
-**Guide**: [Manual Caddy Deployment Guide](docs/Caddy-Deployment.md)

Component licenses:
-NetBird: BSD 3-Clause
-Caddy: Apache 2.0

## Support and Contributions

- Documentation: [docs/](docs/)
- Issues: GitHub issue tracker
- NetBird: [Official documentation](https://docs.netbird.io/)
- Component docs: See respective official documentation
