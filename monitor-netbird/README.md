# NetBird Monitoring Stack (monitor-netbird)

This directory contains the monitoring stack for a self-hosted NetBird control
plane.

Two deployment options are provided:

- **Docker Compose** (single host)
- **Kubernetes + Helm** (K3s or other Kubernetes clusters)

## 1. Docker Compose deployment

The classic deployment uses `docker-compose.yaml` to run:

- Prometheus
- Loki
- Grafana
- Grafana Alloy
- Node Exporter
- Container cgroup metrics exporter
- NetBird events exporter

Configuration files:

- `docker-compose.yaml`
- `prometheus.yml`
- `loki-config.yaml`
- `alloy-config.alloy`

To start the stack:

```bash
docker compose up -d
```

Prometheus will also scrape Docker daemon metrics when `dockerd` is configured
with a metrics endpoint (see comments in `prometheus.yml`).

## 2. Kubernetes + Helm deployment

For clusters (e.g. K3s), a Helm-based deployment lives under
`monitor-netbird/kubernetes/`.

It deploys:

- Prometheus
- Loki
- Grafana
- Mimir

Using persistent volumes sized to stay within a ~10Gi storage budget.

See `monitor-netbird/kubernetes/README.md` for detailed installation and agent
configuration instructions.
