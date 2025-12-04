# NetBird Monitoring Stack on Kubernetes

This directory provides a Kubernetes/Helm deployment of the NetBird monitoring
stack (Prometheus, Loki, Grafana, Mimir) suitable for a small K3s cluster.

It is an alternative to the existing Docker Compose stack in `monitor-netbird/`.

## Components

- **Prometheus**: metrics collection and alerting
- **Loki**: log aggregation with filesystem storage and 30-day retention
- **Grafana**: dashboards and visualization
- **Mimir**: long-term metrics storage via Prometheus remote_write

## Prerequisites

- A running Kubernetes cluster (tested with K3s)
- `kubectl` configured to talk to the cluster
- `helm` installed
- Default StorageClass (e.g. local-path) for PVCs

## Storage Budget

The stack is sized to stay within ~10Gi of persistent storage:

- Loki: 3Gi
- Prometheus: 3Gi
- Mimir: 3Gi
- Grafana: 1Gi

## Deployment

For detailed deployment instructions, including prerequisites, installation steps, and service access, please refer to the main documentation: [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md).


## Uninstall

```bash
helm uninstall monitoring-stack -n monitoring
kubectl delete -f monitor-netbird/kubernetes/namespace.yaml
```

Note: deleting the namespace after uninstalling the chart will remove any
leftover PVCs in the `monitoring` namespace.
