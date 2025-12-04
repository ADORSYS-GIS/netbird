# NetBird observability stack on Kubernetes

This guide explains how to deploy a production-ready observability stack for NetBird on Kubernetes using Helm. The stack includes Prometheus for metrics, Loki for logs, Mimir for long-term metric storage, Tempo for distributed tracing, and Grafana for visualization.

## Overview

The monitoring stack provides:

- **Prometheus**: Metrics collection and short-term storage
- **Loki**: Log aggregation and querying
- **Mimir**: Long-term metrics storage with horizontal scalability
- **Tempo**: Distributed trace collection and analysis
- **Grafana**: Unified dashboard and visualization platform

All components are configured with persistent storage and exposed via NodePort services for external access.

---

## Prerequisites

Before you begin, ensure you have:

- A Kubernetes cluster (K3s, Minikube, EKS, GKE, or AKS)
- `kubectl` configured to access your cluster
- `helm` 3.x or later installed
- At least 15 GB of available storage for persistent volumes
- Basic understanding of Kubernetes resources

---

## Deployment

### 1. Create the monitoring namespace

```bash
kubectl apply -f monitor-netbird/kubernetes/namespace.yaml
```

### 2. Add Helm repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 3. Install the monitoring stack

Navigate to the Helm chart directory and deploy:

```bash
cd monitor-netbird/kubernetes/helm/monitoring-stack
helm dependency update
helm install monitoring-stack . -n monitoring \
  -f ../../configs/loki-values.yaml \
  -f ../../configs/prometheus-values.yaml \
  -f ../../configs/grafana-values.yaml \
  -f ../../configs/mimir-values.yaml \
  -f ../../configs/tempo-values.yaml
cd ../../../../
```

### 4. Apply additional service configurations

Create the Loki and Tempo external access services:

```bash
kubectl apply -f monitor-netbird/kubernetes/configs/loki-nodeport-service.yaml
kubectl apply -f monitor-netbird/kubernetes/configs/tempo-nodeport-service.yaml
```

### 5. Verify deployment

Check that all pods are running:

```bash
kubectl get pods -n monitoring
```

All pods should reach `Running` status within a few minutes. If any pods are not running, check their logs:

```bash
kubectl logs -n monitoring <pod-name>
```

---

## Access and verification

### Access Grafana

Grafana is exposed via NodePort on port `30300`:

```
http://<NODE_IP>:30300
```

**Default credentials:**
- Username: `admin`
- Password: `admin`

> **Important:** Change the admin password immediately after first login, especially in production environments.

### Verify data sources

After logging into Grafana:

1. Navigate to **Connections** → **Data sources**
2. All four data sources should be pre-configured:
   - Prometheus (default)
   - Loki
   - Mimir
   - Tempo
3. Click each data source and select **Save & test**
4. Verify all show green "Data source is working" messages

### Test endpoints

If accessing from a remote machine, set up port forwarding:

```bash
# In separate terminal windows
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/monitoring-stack-prometheus-server 9090:80
kubectl port-forward -n monitoring svc/monitoring-stack-loki-gateway 3100:80
kubectl port-forward -n monitoring svc/monitoring-stack-mimir-nginx 8080:80
kubectl port-forward -n monitoring svc/tempo-external 3200:3200
```

Then test each service:

```bash
# Prometheus health
curl http://localhost:9090/-/healthy

# Loki labels
curl http://localhost:3100/loki/api/v1/labels

# Mimir labels
curl http://localhost:8080/prometheus/api/v1/labels

# Tempo readiness
curl http://localhost:3200/ready

# Grafana health
curl -u admin:admin http://localhost:3000/api/health
```

---

## What gets monitored

### Default metrics collection

The stack automatically scrapes metrics from:

- **Kubernetes cluster components**: API server, nodes, cAdvisor
- **Monitoring stack itself**: Prometheus, Loki, Grafana, Mimir, Tempo
- **CoreDNS**: Kubernetes DNS service
- **Traefik**: Ingress controller (if present)

View active scrape targets:

```
http://<NODE_IP>:30090/targets
```

### Available services

| Service    | NodePort | Internal URL                                        |
|------------|----------|-----------------------------------------------------|
| Grafana    | 30300    | `http://monitoring-stack-grafana:80`                |
| Prometheus | 30090    | `http://monitoring-stack-prometheus-server:80`      |
| Loki       | 31100    | `http://monitoring-stack-loki-gateway:80`           |
| Mimir      | 30080    | `http://monitoring-stack-mimir-nginx:80/prometheus` |
| Tempo      | 31200    | `http://tempo-external:3200`                        |

### Data retention

Default retention periods:

- **Prometheus**: 30 days
- **Loki**: 30 days (720 hours)
- **Mimir**: 30 days (720 hours)
- **Tempo**: 30 days (720 hours)

To modify retention, update the respective values files before deployment.

---

## Exploring data

### Query Prometheus metrics

In Grafana, navigate to **Explore** and select the **Prometheus** data source.

**Example queries:**

```promql
# Cluster CPU usage
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total

# Monitoring stack health
up{job=~"prometheus|loki|grafana|mimir.*|tempo"}
```

### Query Loki logs

Select the **Loki** data source in **Explore**.

**Example queries:**

```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Errors from any service
{namespace="monitoring"} |= "error"

# Loki component logs
{job="loki"}

# Rate of log lines per second
rate({namespace="monitoring"}[1m])
```

### Query Tempo traces

Select the **Tempo** data source in **Explore**.

Use the search interface to:
- Search by service name
- Filter by trace duration
- Find traces with errors
- Explore service dependencies

---

## Adding custom scrape targets

To monitor additional services, add scrape configurations to `prometheus-values.yaml`:

```yaml
prometheus:
  extraScrapeConfigs: |
    - job_name: 'my-application'
      static_configs:
        - targets: ['my-app-service:8080']
          labels:
            environment: 'production'
            team: 'platform'
```

Then upgrade the deployment:

```bash
helm upgrade monitoring-stack ./helm/monitoring-stack -n monitoring \
  -f configs/loki-values.yaml \
  -f configs/prometheus-values.yaml \
  -f configs/grafana-values.yaml \
  -f configs/mimir-values.yaml \
  -f configs/tempo-values.yaml
```

---

## Sending logs to Loki

### Using Promtail

Deploy Promtail as a DaemonSet to collect logs from all cluster nodes:

```bash
helm install promtail grafana/promtail -n monitoring \
  --set "loki.serviceName=monitoring-stack-loki-gateway"
```

### Application-level logging

Configure your applications to send logs directly to Loki:

**Loki push endpoint:**
```
http://monitoring-stack-loki-gateway:80/loki/api/v1/push
```

**Example using Docker logging driver:**

```yaml
logging:
  driver: loki
  options:
    loki-url: "http://<NODE_IP>:31100/loki/api/v1/push"
    labels: "app,environment"
```

---

## Sending traces to Tempo

Configure your applications to send traces to Tempo using OTLP or Jaeger protocols.

### OTLP endpoints

- **gRPC**: `tempo-external:4317` (NodePort: 31317)
- **HTTP**: `tempo-external:4318` (NodePort: 31318)

### Jaeger endpoints

- **Thrift HTTP**: `tempo-external:14268` (NodePort: 31268)

**Example OpenTelemetry configuration:**

```yaml
exporters:
  otlp:
    endpoint: "tempo-external:4317"
    tls:
      insecure: true
```

---

## Troubleshooting

### Pods not starting

Check pod status and events:

```bash
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

Common issues:
- Insufficient resources: Check node capacity with `kubectl top nodes`
- Storage problems: Verify PVCs with `kubectl get pvc -n monitoring`

### Data source connection failures

1. Verify pods are running: `kubectl get pods -n monitoring`
2. Check service endpoints: `kubectl get svc -n monitoring`
3. Test internal connectivity:
   ```bash
   kubectl run -n monitoring test-pod --rm -it --image=curlimages/curl -- sh
   curl http://monitoring-stack-prometheus-server:80/-/healthy
   ```

### No data in Grafana

1. Verify scrape targets in Prometheus: `http://<NODE_IP>:30090/targets`
2. Check Prometheus is scraping: Query `up` in Grafana
3. Verify time range in Grafana matches data retention

### Storage issues

Check persistent volume status:

```bash
kubectl get pv
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring <pvc-name>
```

---

## Production considerations

For production deployments, consider:

### Security

- Enable TLS for all services
- Configure authentication and RBAC
- Use Kubernetes secrets for credentials
- Restrict network policies between namespaces
- Change default passwords immediately

### High availability

- Increase replica counts for stateless components
- Enable zone-aware replication for stateful components
- Configure anti-affinity rules for pod distribution
- Use external load balancers instead of NodePort

### Storage

- Use production-grade storage classes (not `local-path`)
- Configure backup and restore procedures
- Implement appropriate retention policies
- Monitor disk usage and set up alerts

### Scaling

- Adjust resource requests and limits based on load
- Enable horizontal pod autoscaling where applicable
- Consider migrating to distributed deployment modes for Loki and Tempo
- Use Mimir's horizontal scalability for large metric volumes

### Monitoring the monitoring stack

- Set up alerting for monitoring component failures
- Monitor resource usage of monitoring pods
- Track ingestion rates and storage growth
- Configure dead man's switch alerts

---

## Maintenance

### Upgrading components

To upgrade to newer chart versions:

1. Update chart versions in `Chart.yaml`
2. Run `helm dependency update`
3. Review release notes for breaking changes
4. Perform upgrade:
   ```bash
   helm upgrade monitoring-stack ./helm/monitoring-stack -n monitoring \
     -f configs/loki-values.yaml \
     -f configs/prometheus-values.yaml \
     -f configs/grafana-values.yaml \
     -f configs/mimir-values.yaml \
     -f configs/tempo-values.yaml
   ```

### Backup and restore

Export Grafana dashboards:

```bash
# Export all dashboards
kubectl exec -n monitoring <grafana-pod> -- \
  grafana-cli admin export-dashboard > dashboards.json
```

Back up Prometheus data:

```bash
# Copy data directory from PVC
kubectl cp monitoring/<prometheus-pod>:/data ./prometheus-backup
```

---

## Uninstalling

To remove the monitoring stack:

```bash
# Delete Helm release
helm uninstall monitoring-stack -n monitoring

# Delete additional services
kubectl delete -f monitor-netbird/kubernetes/configs/loki-nodeport-service.yaml
kubectl delete -f monitor-netbird/kubernetes/configs/tempo-nodeport-service.yaml

# Delete namespace (removes all resources and PVCs)
kubectl delete namespace monitoring
```

> **Warning:** This permanently deletes all monitoring data. Back up important data before proceeding.

---

## Additional resources

- [Prometheus documentation](https://prometheus.io/docs/)
- [Loki documentation](https://grafana.com/docs/loki/latest/)
- [Mimir documentation](https://grafana.com/docs/mimir/latest/)
- [Tempo documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana documentation](https://grafana.com/docs/grafana/latest/)
- [Helm documentation](https://helm.sh/docs/)

For Docker Compose deployment instructions, refer to [Monitoring-NetBird-Observability-Docker-Compose.md](Monitoring-NetBird-Observability-Docker-Compose.md).