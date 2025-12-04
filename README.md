# NetBird Infrastructure and Monitoring

This repository contains automation and configuration for deploying supporting
infrastructure around self‑hosted NetBird, including identity (Keycloak) and a
Grafana‑based monitoring stack.

---

## 1. Keycloak deployment (Ansible)

Ansible automation is provided for deploying Keycloak as an identity provider.

### Quick start

1. Update inventory: `deploy/inventory.ini`
2. Configure variables: `deploy/group_vars/keycloak.yml`
3. Run: `ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml`

### Layout

```
├── deploy/
│   ├── roles/keycloak/         # Keycloak Ansible role
│   ├── group_vars/             # Variable configuration
│   ├── inventory.ini           # Target hosts
│   └── deploy_keycloak.yml     # Main playbook
└── docs/                       # Documentation
```

### Key features

- Automated Keycloak deployment with PostgreSQL
- Realm and client configuration
- Reverse‑proxy‑ready design
- External Keycloak support
- Secure credential management

See [docs/keycloak-role.md](docs/keycloak-role.md) for detailed Keycloak
instructions.

---

## 2. NetBird monitoring stack (Prometheus, Loki, Grafana)

The `monitor-netbird/` directory provides a production‑style observability stack
for a self‑hosted NetBird control plane. It includes:

- Prometheus for metrics
- Loki for logs
- Grafana for dashboards
- Grafana Alloy for log collection
- Host and container metrics exporters
- A NetBird events exporter that forwards management events to Loki

High‑level operator documentation for deploying and managing the monitoring stack is available:

-   **Docker Compose Deployment:** [`docs/Monitoring-NetBird-Observability-Docker-Compose.md`](docs/Monitoring-NetBird-Observability-Docker-Compose.md)
-   **Kubernetes Deployment (Helm):** [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md)

The NetBird events exporter used by the monitoring stack has its own short
overview:

- [monitor-netbird/exporter/README.md](monitor-netbird/exporter/README.md)

---

## 3. Additional documentation

All documentation lives under the `docs/` tree. Start with:

- [`docs/keycloak-role.md`](docs/keycloak-role.md)
- [`docs/Monitoring-NetBird-Observability-Docker-Compose.md`](docs/Monitoring-NetBird-Observability-Docker-Compose.md)
- [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md)
