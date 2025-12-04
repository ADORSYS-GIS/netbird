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

## Install

From the repository root:

```bash
kubectl apply -f monitor-netbird/kubernetes/namespace.yaml

cd monitor-netbird/kubernetes/helm/monitoring-stack
helm dependency update

helm install monitoring-stack . \
  -n monitoring \
  -f ../../configs/loki-values.yaml \
  -f ../../configs/prometheus-values.yaml \
  -f ../../configs/grafana-values.yaml \
  -f ../../configs/mimir-values.yaml

# Loki service is ClusterIP by default; apply NodePort service for external access
kubectl apply -f ../configs/loki-nodeport-service.yaml -n monitoring
```

## Service Access (NodePort)

By default the stack exposes the following NodePorts:

- Grafana: `30300` (HTTP 3000)
- Prometheus: `30090` (HTTP 9090)
- Loki: `31100` (HTTP 3100)
- Mimir: `30080` (HTTP 8080)

You can reach these services using any IP or DNS name that resolves to a cluster
node (for example, a LAN IP, VPN address, or hostname):

- Grafana: `http://<monitoring-host>:30300`
- Prometheus: `http://<monitoring-host>:30090`
- Loki: `http://<monitoring-host>:31100`
- Mimir: `http://<monitoring-host>:30080`

## Verify Service Names

After installation, verify the actual service names in the cluster:

```bash
kubectl get svc -n monitoring
```

If service names differ from the defaults used in the configuration files
(`prometheus-server`, `loki`, `grafana`, `mimir-distributed-query-frontend`),
you may need to update the datasource URLs in `grafana-values.yaml` and the
scrape targets in `prometheus-values.yaml` to match the actual service names.

Service names typically follow the pattern: `<release-name>-<service-name>`
(e.g., `monitoring-stack-prometheus-server`).

## External Agents and Targets

The `agents/` directory contains guidance and examples for running exporters on
Linux hosts that are reachable from the monitoring stack (for example, over a
VPN, overlay network, corporate network, or local LAN):

- Node Exporter for host metrics
- Docker daemon metrics (as an alternative to cAdvisor)
- Alloy for system and container logs
- NetBird events exporter to push management events to Loki

See `agents/README.md` for details.

## Uninstall

```bash
helm uninstall monitoring-stack -n monitoring
kubectl delete -f monitor-netbird/kubernetes/namespace.yaml
```

Note: deleting the namespace after uninstalling the chart will remove any
leftover PVCs in the `monitoring` namespace.
