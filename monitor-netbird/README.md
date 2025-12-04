# NetBird monitoring stack

Production-ready observability stack for self-hosted NetBird deployments. Provides comprehensive metrics, logs, and distributed tracing with Grafana visualization.

## Components

- **Prometheus**: Metrics collection and alerting
- **Loki**: Log aggregation and querying
- **Mimir**: Long-term metric storage
- **Tempo**: Distributed tracing
- **Grafana**: Unified visualization platform
- **NetBird events exporter**: Custom exporter for NetBird control plane ([README](exporter/README.md))

## Deployment options

### Docker Compose (single host)

Quick deployment for development or single-server setups:

```bash
docker compose up -d
```

Access Grafana at `http://localhost:3000` (admin/admin)

**📖 Full guide:** [Monitoring-NetBird-Observability-Docker-Compose.md](../docs/Monitoring-NetBird-Observability-Docker-Compose.md)

### Kubernetes (production)

Helm-based deployment for production clusters:

```bash
cd kubernetes
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

Access Grafana at `http://<NODE_IP>:30300`

**📖 Full guide:** [Monitoring-NetBird-Observability-Kubernetes.md](../docs/Monitoring-NetBird-Observability-Kubernetes.md)

## Configuration files

### Docker Compose
- `docker-compose.yaml`: Service definitions
- `prometheus.yml`: Prometheus scrape configuration
- `loki-config.yaml`: Loki storage and retention settings
- `alloy-config.alloy`: Grafana Alloy telemetry collector

### Kubernetes
- `kubernetes/configs/`: Helm values files for all components
- `kubernetes/helm/monitoring-stack/`: Umbrella Helm chart
- `kubernetes/namespace.yaml`: Monitoring namespace definition

## Quick verification

After deployment, verify all services are healthy:

**Docker Compose:**
```bash
docker compose ps
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/ready       # Loki
```

**Kubernetes:**
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

## Data retention

Default retention periods (configurable in values files):

- Prometheus: 30 days
- Loki: 30 days (720h)
- Mimir: 30 days (720h)
- Tempo: 30 days (720h)

## Storage requirements

**Docker Compose:** Volumes managed by Docker
**Kubernetes:** ~13 GiB persistent storage (1Gi Grafana + 3Gi × 4 components)

## Documentation

- **[Docker Compose deployment guide](../docs/Monitoring-NetBird-Observability-Docker-Compose.md)**: Complete setup for single-host deployments
- **[Kubernetes deployment guide](../docs/Monitoring-NetBird-Observability-Kubernetes.md)**: Production-ready Helm installation
- **[NetBird events exporter](exporter/README.md)**: Custom exporter for NetBird metrics and events

## Next steps

1. Access Grafana and verify data sources
2. Configure scrape targets for your services
3. Deploy NetBird events exporter for control plane monitoring
4. Create custom dashboards for your infrastructure
5. Set up alerting rules in Prometheus

For detailed instructions on adding monitoring targets, log shipping, and trace collection, refer to the deployment guides above.