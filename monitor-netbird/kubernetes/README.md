# Kubernetes deployment

Helm-based deployment of the NetBird monitoring stack for Kubernetes clusters.

## Quick start

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy stack
cd helm/monitoring-stack
helm dependency update
helm install monitoring-stack . -n monitoring \
  -f ../../configs/loki-values.yaml \
  -f ../../configs/prometheus-values.yaml \
  -f ../../configs/grafana-values.yaml \
  -f ../../configs/mimir-values.yaml \
  -f ../../configs/tempo-values.yaml

# Apply NodePort services
kubectl apply -f ../../configs/loki-nodeport-service.yaml
kubectl apply -f ../../configs/tempo-nodeport-service.yaml
```

## Components deployed

- Prometheus (30090) - Metrics
- Loki (31100) - Logs  
- Mimir (30080) - Long-term metrics
- Tempo (31200) - Traces
- Grafana (30300) - Dashboards

## Storage

Total: ~13 GiB persistent storage
- Grafana: 1 GiB
- Prometheus: 3 GiB
- Loki: 3 GiB
- Mimir: 3 GiB (ingester + store-gateway + compactor)
- Tempo: 3 GiB

## Configuration

All configuration in `configs/`:
- `*-values.yaml`: Helm chart overrides
- `*-nodeport-service.yaml`: External access services

## Full documentation

**📖 Complete guide:** [docs/Monitoring-NetBird-Observability-Kubernetes.md](../../docs/Monitoring-NetBird-Observability-Kubernetes.md)

Includes:
- Detailed installation steps
- Service access and verification
- Adding scrape targets
- Log and trace collection setup
- Troubleshooting
- Production considerations

## Uninstall

```bash
helm uninstall monitoring-stack -n monitoring
kubectl delete -f configs/loki-nodeport-service.yaml
kubectl delete -f configs/tempo-nodeport-service.yaml
kubectl delete namespace monitoring
```

> **Warning:** This deletes all monitoring data. Back up important dashboards and data before proceeding.