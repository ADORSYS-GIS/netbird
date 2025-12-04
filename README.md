# NetBird infrastructure and monitoring

This repository provides deployment automation and observability tooling for self-hosted NetBird infrastructure. It includes identity provider setup via Ansible and a complete Grafana-based monitoring stack deployable on Docker Compose or Kubernetes.

## Key Features

## Overview

### What's included

**Identity management**
- Automated Keycloak deployment with PostgreSQL
- NetBird realm and client configuration
- Reverse-proxy integration support

**Observability stack**
- Prometheus for metrics collection and alerting
- Loki for log aggregation and search
- Mimir for long-term metric storage
- Tempo for distributed tracing
- Grafana for unified visualization
- NetBird events exporter for control plane monitoring

**Deployment options**
- Docker Compose for single-host deployments
- Kubernetes (Helm) for production clusters

---

## Quick start

### Deploy Keycloak (Ansible)

1. Configure your target hosts in `deploy/inventory.ini`
2. Set deployment variables in `deploy/group_vars/keycloak.yml`
3. Run the playbook:
   ```bash
   ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml
   ```

Refer to [docs/keycloak-role.md](docs/keycloak-role.md) for detailed configuration options.

### Deploy monitoring stack

Choose your deployment method:

**Docker Compose (single host)**
```bash
cd monitor-netbird
docker compose up -d
```

**Kubernetes (production)**
```bash
cd monitor-netbird/kubernetes
kubectl apply -f namespace.yaml
cd helm/monitoring-stack
helm dependency update
helm install monitoring-stack . -n monitoring \
  -f ../../configs/loki-values.yaml \
  -f ../../configs/prometheus-values.yaml \
  -f ../../configs/grafana-values.yaml \
  -f ../../configs/mimir-values.yaml \
  -f ../../configs/tempo-values.yaml
```

Access Grafana at `http://localhost:3000` (Docker) or `http://<NODE_IP>:30300` (Kubernetes).

**Default credentials:** `admin` / `admin`

---

## Documentation

### Deployment guides

- **[Keycloak deployment](docs/keycloak-role.md)**: Complete Ansible automation guide for identity provider setup
- **[Docker Compose monitoring](docs/Monitoring-NetBird-Observability-Docker-Compose.md)**: Deploy observability stack on single host
- **[Kubernetes monitoring](docs/Monitoring-NetBird-Observability-Kubernetes.md)**: Production-ready Helm deployment on Kubernetes

### Additional resources

- **[NetBird events exporter](monitor-netbird/exporter/README.md)**: Custom exporter for NetBird control plane events and metrics
- **[Caddy deployment](docs/Caddy-Deployment.md)**: Reverse proxy configuration for NetBird services
- **[Keycloak role mapping](docs/keycloak-role.md)**: Identity provider integration details

---

## Repository structure

```
.
├── deploy/                          # Ansible automation
│   ├── roles/keycloak/              # Keycloak role
│   ├── group_vars/                  # Configuration variables
│   ├── inventory.ini                # Target hosts
│   └── deploy_keycloak.yml          # Main playbook
├── monitor-netbird/                 # Observability stack
│   ├── docker-compose.yml           # Docker deployment
│   ├── kubernetes/                  # Kubernetes deployment
│   │   ├── configs/                 # Helm values files
│   │   ├── helm/monitoring-stack/   # Umbrella chart
│   │   └── namespace.yaml           # Kubernetes namespace
│   ├── exporter/                    # NetBird events exporter
│   └── prometheus/                  # Prometheus configuration
└── docs/                            # Documentation
    ├── Monitoring-NetBird-Observability-Docker-Compose.md
    ├── Monitoring-NetBird-Observability-Kubernetes.md
    ├── keycloak-role.md
    └── img/                         # Screenshots and diagrams
```

---

## Components

### Keycloak identity provider

- PostgreSQL backend for persistent storage
- Pre-configured NetBird realm
- OAuth2/OIDC client setup
- Custom role and group mappings
- TLS-ready configuration

### Monitoring stack

**Metrics**
- Prometheus: Short-term storage, alerting, and scraping
- Mimir: Long-term metric storage with horizontal scalability
- Node exporter: Host-level system metrics

**Logs**
- Loki: Log aggregation with label-based indexing
- Promtail: Log shipper for Docker and Kubernetes
- Grafana Alloy: Unified telemetry collector (optional)

**Traces**
- Tempo: Distributed tracing backend
- OTLP and Jaeger protocol support
- Integration with Prometheus and Loki for trace correlation

**Visualization**
- Grafana: Unified dashboard platform
- Pre-configured data sources
- NetBird-specific dashboards (via exporter)

---

## Features

### Keycloak automation

- Idempotent Ansible playbooks
- Secure credential management
- Support for external Keycloak instances
- Reverse proxy integration (Nginx, Caddy, Traefik)
- Realm export/import capabilities

### Monitoring capabilities

- Self-monitoring: Stack observes its own health
- Multi-tenancy support via Mimir
- Distributed tracing with service maps
- Log and metric correlation
- NetBird control plane events tracking
- Custom alerting rules
- Persistent storage with configurable retention

### Deployment flexibility

- Single-command Docker Compose setup
- Production-ready Kubernetes Helm charts
- NodePort and LoadBalancer service types
- Configurable resource limits
- Persistent volume management
- High availability options (Kubernetes)

## Getting Started with Ansible Automation

## Production considerations

### Security

- Change default credentials immediately
- Enable TLS for all services
- Configure authentication and RBAC
- Use Kubernetes secrets for sensitive data
- Implement network policies
- Regular security updates

### High availability

- Run multiple replicas for stateless components
- Enable zone-aware replication (Kubernetes)
- Configure anti-affinity rules
- Use external load balancers
- Implement health checks and readiness probes

### Scalability

- Mimir supports horizontal scaling for metrics
- Loki can scale reads and writes independently
- Tempo distributed mode for high trace volumes
- Resource requests and limits tuning
- Storage class selection for performance

### Monitoring

- Alert on monitoring stack health
- Track ingestion rates and storage growth
- Monitor resource consumption
- Dead man's switch for alerting pipeline
- Backup and disaster recovery procedures


We welcome contributions to the NetBird project!

## Next steps

### After Keycloak deployment

- [`docs/Monitoring-NetBird-Observability-Docker-Compose.md`](docs/Monitoring-NetBird-Observability-Docker-Compose.md)
- [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md)

1. Configure NetBird to use Keycloak as IDP
2. Create user accounts and groups
3. Test OAuth2 authentication flow
4. Configure role-based access control

### After monitoring stack deployment

1. Verify all data sources in Grafana
2. Add scrape targets for your services
3. Configure log shipping to Loki
4. Set up trace collection to Tempo
5. Create custom dashboards
6. Configure alerting rules
7. Implement backup procedures

### Integrations

- Deploy NetBird events exporter for control plane monitoring
- Configure Grafana Alloy for unified telemetry collection
- Add Prometheus exporters for external services
- Create custom recording and alerting rules
- Build team-specific dashboards

---

## Troubleshooting

### Keycloak issues

```bash
# Check Ansible playbook output
ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml -vv

# Verify Keycloak service status
systemctl status keycloak

# Check PostgreSQL connectivity
psql -U keycloak -d keycloak -h localhost
```

### Monitoring stack issues

**Docker Compose**
```bash
# Check service status
docker compose -f monitor-netbird/docker-compose.yml ps

# View logs
docker compose -f monitor-netbird/docker-compose.yml logs <service>

# Restart services
docker compose -f monitor-netbird/docker-compose.yml restart
```

**Kubernetes**
```bash
# Check pod status
kubectl get pods -n monitoring

# View pod logs
kubectl logs -n monitoring <pod-name>

# Describe pod for events
kubectl describe pod -n monitoring <pod-name>

# Test data source connectivity
kubectl run -n monitoring test-pod --rm -it --image=curlimages/curl -- sh
```

---

## License

This project is provided as-is for use with self-hosted NetBird deployments. Refer to individual component licenses:

- Keycloak: Apache License 2.0
- Prometheus: Apache License 2.0
- Loki: AGPL-3.0
- Mimir: AGPL-3.0
- Tempo: AGPL-3.0
- Grafana: AGPL-3.0

---

## Support

For issues and questions:

- Check the [documentation](docs/)
- Review [troubleshooting guides](#troubleshooting)
- Open a GitHub issue
- Refer to upstream component documentation

For NetBird-specific questions, consult the [official NetBird documentation](https://docs.netbird.io/).
