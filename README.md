# NetBird Infrastructure

## Overview

Production-grade infrastructure automation for self-hosted [NetBird](https://netbird.io) on Kubernetes with Keycloak OIDC authentication.

**Architecture**: LoadBalancer → Ingress (TLS via cert-manager) → NetBird services (dashboard, management, signal gRPC, relay WebSocket)

## Deployment Options

### 1. Terraform + Helm (Recommended)

Fully declarative deployment using Terraform modules and the [official NetBird Helm chart](https://artifacthub.io/packages/helm/netbird/netbird) (v1.9.0).

- **Guide**: [Quick Start Tutorial](tutorial/01-quick-start.md)
- **Terraform**: [infrastructure/terraform/](infrastructure/terraform/)

**Features**:
- Configures an **existing Keycloak** instance (realm, dual OIDC clients, groups, JWT mappers, admin user)
- Deploys NetBird via Helm (dashboard, management, signal, relay)
- Optional cert-manager and ingress-nginx installation
- Cloud SQL PostgreSQL or SQLite database support
- Production-hardened: brute-force protection, PKCE, gRPC HTTP/2, Kubernetes Secrets

### 2. Ansible (Legacy)

Ansible-based deployment with Caddy reverse proxy.

- **Guide**: [Ansible Deployment Guide](infrastructure/ansible/README.md)

### 3. Quick Script (Dev/Test)

Quickstart with Zitadel IdP using the setup script.

- **Guide**: [Quickstart with Zitadel](infrastructure/scripts/README.md)

## Documentation

| Document | Description |
|----------|-------------|
| [Keycloak Integration](docs/keycloak-integration.md) | Dual-client architecture, JWT groups, device auth flow |
| [Troubleshooting](docs/troubleshooting.md) | OIDC, certs, ingress, gRPC, connectivity issues |
| [Upgrade Guide](docs/upgrade-guide.md) | Chart upgrades, rollbacks, provider migration |
| [Architecture](docs/architecture.md) | System architecture and design |

## Tutorials

| Tutorial | Description |
|----------|-------------|
| [01 — Quick Start](tutorial/01-quick-start.md) | From clone to first login in 6 steps |
| [02 — Peers & ACLs](tutorial/02-adding-peers-and-acls.md) | Connect devices, create groups, configure access rules |
| [03 — User Management](tutorial/03-keycloak-user-management.md) | Keycloak user lifecycle, group sync, access revocation |

## Support

- [NetBird Official Docs](https://docs.netbird.io/)
- [NetBird Keycloak Guide](https://docs.netbird.io/selfhosted/identity-providers/keycloak)
- Issues: GitHub issue tracker
