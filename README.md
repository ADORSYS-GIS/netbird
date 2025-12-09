# NetBird Infrastructure and Observability

Production-grade infrastructure automation and observability stack for self-hosted NetBird deployments.

## What's Included

### Identity Management
- Automated Keycloak deployment with PostgreSQL backend
- Pre-configured NetBird realm and client settings
- Reverse proxy integration support via Caddy

### Observability Stack
- **Prometheus**: Metrics collection and alerting
- **Loki**: Log aggregation and search
- **Mimir**: Long-term metric storage with horizontal scalability
- **Tempo**: Distributed tracing
- **Grafana**: Unified visualization dashboard
- **NetBird Events Exporter**: Control plane monitoring

### Deployment Options
- **Docker Compose**: Single-host deployments for development and testing
- **Kubernetes (Helm)**: Production-ready cluster deployments with GCS backend

## Quick Start

### Prerequisites
- Target infrastructure (Linux hosts for Ansible, Kubernetes cluster for Helm)
- Docker and Docker Compose (for single-host deployments)
- kubectl and Helm 3.x (for Kubernetes deployments)
- Ansible 2.9+ (for Keycloak automation)

### Deploy Keycloak with Ansible

1. Configure target hosts in `deploy/inventory.ini`
2. Set deployment variables in `deploy/group_vars/keycloak.yml`
3. Run the playbook:
   ```bash
   ansible-playbook -i deploy/inventory.ini deploy/deploy_keycloak.yml
   ```

See [Keycloak Deployment Guide](docs/keycloak-role.md) for detailed configuration.

### Deploy Observability Stack

#### Docker Compose (Development/Testing)
```bash
cd monitor-netbird
docker compose up -d
```

Access Grafana at `http://localhost:3000` with default credentials `admin/admin`.

See [Docker Compose Monitoring Guide](docs/Monitoring-NetBird-Observability-Docker-Compose.md) for details.

#### Kubernetes (Production)

* See [Terraform Infrastructure Guide](monitor-netbird/kubernetes/terraform/README.md) for GCP resource provisioning.

* See [Kubernetes Monitoring Guide](docs/Monitoring-NetBird-Observability-Kubernetes.md) for complete setup instructions.

## Documentation

### Deployment Guides
- [Keycloak Ansible Deployment](docs/keycloak-role.md): Identity provider automation
- [Docker Compose Monitoring](docs/Monitoring-NetBird-Observability-Docker-Compose.md): Single-host observability
- [Kubernetes Monitoring](docs/Monitoring-NetBird-Observability-Kubernetes.md): Production cluster deployment
- [Terraform Infrastructure](monitor-netbird/kubernetes/terraform/README.md): GCP resource provisioning

### Component Documentation
- [NetBird Events Exporter](monitor-netbird/exporter/README.md): Custom metrics exporter
- [Caddy Reverse Proxy](docs/Caddy-Deployment.md): Reverse proxy configuration

### External Resources
- [NetBird Documentation](https://docs.netbird.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## Architecture Overview

### Docker Compose Stack
```
┌─────────────────────────────────────────┐
│         Grafana (Port 3000)             │
│              Dashboards                 │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┬──────────┬─────────┐
    │                 │          │         │
┌───▼────┐     ┌─────▼─────┐ ┌──▼───┐ ┌───▼────┐
│Prometh-│     │   Loki    │ │Mimir │ │ Tempo  │
│ eus    │     │           │ │      │ │        │
└────────┘     └───────────┘ └──────┘ └────────┘
```

### Kubernetes Stack
```
┌──────────────────────────────────────────┐
│   Ingress (TLS via cert-manager)         │
└────────────┬─────────────────────────────┘
             │
    ┌────────┴────────┬──────────┬─────────┐
    │                 │          │         │
┌───▼────┐     ┌─────▼─────┐ ┌──▼───┐  ┌───▼────┐
│Grafana │     │Prometheus │ │Loki  │  │ Mimir  │
│        │     │           │ │      │  │        │
└────────┘     └───────────┘ └──┬───┘  └───┬────┘
                                │          │
                           ┌────▼──────────▼─────┐
                           │  GCS Buckets        │
                           │  (Object Storage)   │
                           └─────────────────────┘
```


## Production Considerations

### Security
- Change default Grafana credentials immediately
- Enable TLS for all external endpoints
- Configure RBAC for Kubernetes deployments
- Use secrets management for sensitive data
- Implement network policies between namespaces

### High Availability
- Run multiple replicas for stateless components
- Distribute pods across availability zones
- Configure pod disruption budgets
- Use external load balancers in production

### Storage
- Use production-grade storage classes
- Configure appropriate retention policies
- Implement backup and restore procedures
- Monitor disk usage and set alerts

### Monitoring
- Set up alerting for component failures
- Monitor ingestion rates and storage growth
- Configure dead man's switch alerts
- Track resource usage of monitoring pods

## Troubleshooting

### Common Issues

**Pods not starting**
```bash
kubectl describe pod -n observability <pod-name>
kubectl logs -n observability <pod-name>
```

**Data source connection failures**
1. Verify pods are running: `kubectl get pods -n observability`
2. Check service endpoints: `kubectl get svc -n observability`
3. Test internal connectivity from a debug pod

**Storage issues**
```bash
kubectl get pv
kubectl get pvc -n observability
kubectl describe pvc -n observability <pvc-name>
```

See component-specific documentation for detailed troubleshooting.

## Default Retention Periods

| Component  | Retention | Configurable In |
|------------|-----------|-----------------|
| Prometheus |  7 days   | prometheus-values.yaml |
| Loki       | 30 days   | loki-values.yaml |
| Mimir      | 30 days   | mimir-values.yaml |
| Tempo      | 30 days   | tempo-values.yaml |

## License

This project is provided as-is for self-hosted NetBird deployments.

Component licenses:
- Keycloak: Apache License 2.0
- Prometheus: Apache License 2.0
- Loki: AGPL-3.0
- Mimir: AGPL-3.0
- Tempo: AGPL-3.0
- Grafana: AGPL-3.0

## Support

- Documentation: [docs/](docs/)
- Issues: GitHub issue tracker
- NetBird: [Official documentation](https://docs.netbird.io/)
- Component docs: See respective official documentation
