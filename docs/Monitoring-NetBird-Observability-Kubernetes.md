# Observability Stack on Kubernetes

Production deployment of Prometheus, Loki, Mimir, Tempo, and Grafana on Kubernetes with persistent storage and TLS ingress.

## What This Deploys

A complete observability stack ready to monitor any Kubernetes workload:

- **Prometheus**: Metrics collection (7-day retention)
- **Loki**: Log aggregation with GCS backend (30-day retention)
- **Mimir**: Scalable long-term metrics (30-day retention)
- **Tempo**: Distributed tracing with GCS backend (30-day retention)
- **Grafana**: Unified visualization

This stack is deployment-agnostic. While it can monitor NetBird, it works with any application or infrastructure.

## Prerequisites

### Required
- Kubernetes cluster (K3s, EKS, GKE, or AKS)
- kubectl configured with cluster access
- Helm 3.x or later
- Sufficient storage for persistent volumes

### GKE-Specific
For GKE with GCS backends:
1. Complete [Terraform Infrastructure Setup](../monitor-netbird/kubernetes/terraform/README.md)
2. Update Helm values with bucket names and service account
3. Ensure Workload Identity is enabled on cluster

### Optional
- cert-manager for TLS certificates
- Ingress controller (NGINX recommended)
- external-dns for automatic DNS management

## Deployment

### Step 1: Create Namespaces

```bash
kubectl apply -f monitor-netbird/kubernetes/namespace.yaml # If it doesn't already exist
kubectl create namespace cert-manager
kubectl create namespace ingress-nginx
```

### Step 2: Add Helm Repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 3: Install cert-manager (Optional)

Required for TLS with Let's Encrypt:

```bash
# Install CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.15.0 \
  --set installCRDs=false

# Wait for ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

# Apply ClusterIssuer
kubectl apply -f monitor-netbird/kubernetes/configs/cert-manager/cluster-issuer.yaml
```

### Step 4: Install Ingress Controller (Optional)

For external access:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer

# Get external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Configure DNS A records pointing to this IP.

### Step 5: Configure Helm Values

Edit files in `monitor-netbird/kubernetes/configs/monitoring-services/` to match your environment.

**Critical placeholders to replace:**

| Placeholder | Description | Files |
|-------------|-------------|-------|
| `<PROJECT_ID>` | GCP project ID | All GCS bucket references |
| `<GCP_SERVICE_ACCOUNT_EMAIL>` | Workload Identity email | All *-values.yaml |
| `<GRAFANA_DOMAIN_NAME>` | Grafana domain | grafana-values.yaml, monitoring-ingress.yaml |
| `<LOKI_DOMAIN_NAME>` | Loki domain | loki-values.yaml, monitoring-ingress.yaml |
| `<YOUR_MONITORING_DOMAIN>` | Base domain | monitoring-ingress.yaml |
| `<*_BUCKET_NAME>` | GCS bucket names | loki-values.yaml, mimir-values.yaml, tempo-values.yaml |
| `<CLUSTER_NAME>` | Cluster identifier | prometheus-values.yaml |
| `<ENVIRONMENT>` | Environment name | prometheus-values.yaml |
| `<YOUR_EMAIL_ADDRESS>` | Let's Encrypt email | cluster-issuer.yaml |

### Step 6: Deploy Monitoring Stack

```bash
cd monitor-netbird/kubernetes/helm/monitoring-stack
helm dependency update
helm install monitoring-stack . -n observability \
  -f ../../configs/monitoring-services/loki-values.yaml \
  -f ../../configs/monitoring-services/prometheus-values.yaml \
  -f ../../configs/monitoring-services/grafana-values.yaml \
  -f ../../configs/monitoring-services/mimir-values.yaml \
  -f ../../configs/monitoring-services/tempo-values.yaml
cd ../../../../
```

### Step 7: Apply Ingress Resources

**For TLS Ingress:**
```bash
kubectl apply -f monitor-netbird/kubernetes/configs/cert-manager/monitoring-ingress.yaml
```

### Step 8: Verify Deployment

```bash
kubectl get pods -n observability
kubectl get svc -n observability
kubectl get ingress -n observability
```

All pods should reach Running status within 5 minutes. Check logs if issues occur:
```bash
kubectl logs -n observability <pod-name> --tail=50
```

## Access Grafana

**Via Ingress:**
```
https://<GRAFANA_DOMAIN_NAME>
```

**Via NodePort:**
```
http://<NODE_IP>:30300
```

**Default credentials:** `admin` / `admin`

Change the password immediately after first login.

### Configure Data Sources

Data sources are pre-configured in `grafana-values.yaml`. Verify each:

1. Go to Connections > Data sources
2. Test each data source:
   - **Prometheus**: `http://monitoring-stack-prometheus-server:80`
   - **Loki**: `http://monitoring-stack-loki-gateway:80`
   - **Mimir**: `http://monitoring-stack-mimir-nginx:80/prometheus`
   - **Tempo**: `http://monitoring-stack-tempo-query-frontend:3200`
3. Click Save & test for each

## Monitoring Your Applications

### Collect Metrics

Prometheus automatically scrapes:
- Kubernetes components (API server, nodes, cAdvisor)
- kube-state-metrics
- Monitoring stack components

**Add custom scrape targets** in `prometheus-values.yaml`:

```yaml
prometheus:
  extraScrapeConfigs: |
    - job_name: 'my-application'
      static_configs:
        - targets: ['my-app-service:8080']
          labels:
            environment: 'production'
```

Then upgrade:
```bash
helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
  -f configs/monitoring-services/*.yaml
```

View active targets: `http://<PROMETHEUS_DOMAIN>/targets`

### Collect Logs

**Deploy Promtail** for cluster-wide log collection:
```bash
helm install promtail grafana/promtail -n observability \
  --set "loki.serviceName=monitoring-stack-loki-gateway"
```

**Direct log ingestion:**
```
POST http://monitoring-stack-loki-gateway:80/loki/api/v1/push
```

### Collect Traces

Configure applications to send traces to Tempo:

**OTLP endpoints:**
- gRPC: `https://tempo-grpc.<YOUR_MONITORING_DOMAIN>:443`
- HTTP: `https://tempo-push.<YOUR_MONITORING_DOMAIN>/v1/traces`

**Example OpenTelemetry config:**
```yaml
exporters:
  otlp:
    endpoint: "https://tempo-grpc.<YOUR_MONITORING_DOMAIN>:443"
    tls:
      insecure: false
```

## Query Examples

### Prometheus

```promql
# CPU usage by node
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# Memory by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restarts
kube_pod_container_status_restarts_total

# Stack health
up{job=~"prometheus|loki|grafana|mimir.*|tempo"}
```

### Loki

```logql
# All logs from namespace
{namespace="observability"}

# Error logs
{namespace="observability"} |= "error"

# Log rate
rate({namespace="observability"}[1m])

# Parse JSON logs
{namespace="observability"} | json | level="error"
```

### Tempo

Use the search interface to filter by service name, span duration, status, or query by trace ID directly.

## Retention and Storage

### Default Retention

| Component  | Retention | File |
|------------|-----------|------|
| Prometheus | 7 days    | prometheus-values.yaml |
| Loki       | 30 days   | loki-values.yaml |
| Mimir      | 30 days   | mimir-values.yaml |
| Tempo      | 30 days   | tempo-values.yaml |

### Modify Retention

Edit the values file and upgrade:

**Prometheus:**
```yaml
prometheus:
  server:
    retention: 7d
```

**Loki:**
```yaml
loki:
  loki:
    limits_config:
      retention_period: 720h
```

**Mimir:**
```yaml
mimir-distributed:
  mimir:
    structuredConfig:
      blocks_storage:
        tsdb:
          retention_period: 720h
```

**Tempo:**
```yaml
tempo:
  tempo:
    compactor:
      compaction:
        block_retention: 720h
```

Apply changes:
```bash
helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
  -f configs/monitoring-services/*.yaml
```

### Persistent Volumes

Default sizes:

| Component | Size | Storage Class |
|-----------|------|---------------|
| Prometheus | 3Gi | default |
| Loki | 5Gi | standard-rwo |
| Mimir | 3Gi per component | default |
| Tempo | 3Gi | default |
| Grafana | 1Gi | default |

Check volumes:
```bash
kubectl get pv
kubectl get pvc -n observability
```

## Production Hardening

### Security

**Immediate:**
- Change default Grafana password
- Enable TLS for external endpoints
- Configure authentication (OAuth, LDAP, SAML)

**Network Policy example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: observability-policy
  namespace: observability
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      - namespaceSelector:
          matchLabels:
            name: observability
```

### High Availability

Increase replicas in values files:

```yaml
# loki-values.yaml
loki:
  singleBinary:
    replicas: 3

# mimir-values.yaml
mimir-distributed:
  distributor:
    replicas: 3
  ingester:
    replicas: 3
    zoneAwareReplication:
      enabled: true
```

**PodDisruptionBudget example:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: loki-pdb
  namespace: observability
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: loki
```

### Resource Management

Set requests and limits:
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

Monitor usage:
```bash
kubectl top pods -n observability
kubectl top nodes
```

## Troubleshooting

### Pod Issues

```bash
kubectl describe pod -n observability <pod-name>
kubectl logs -n observability <pod-name> --previous
```

Common causes: insufficient resources, storage failures, image pull errors, configuration errors.

### Data Source Failures

1. Check pod health: `kubectl get pods -n observability`
2. Check endpoints: `kubectl get endpoints -n observability`
3. Test connectivity:
   ```bash
   kubectl run -n observability test-pod --rm -it \
     --image=curlimages/curl -- sh
   # Test each service
   curl http://monitoring-stack-prometheus-server:80/-/healthy
   curl http://monitoring-stack-loki-gateway:80/ready
   ```

### Ingress Issues

```bash
kubectl describe ingress -n observability monitoring-stack-ingress
kubectl get certificate -n observability
kubectl logs -n cert-manager -l app=cert-manager
```

Common issues: DNS not pointing to Ingress IP, ClusterIssuer not ready, Let's Encrypt rate limits.

### Storage Issues

```bash
kubectl get pv
kubectl get pvc -n observability
kubectl describe pvc -n observability <pvc-name>
```

Common causes: storage class unavailable, insufficient capacity, node affinity constraints.

### GCS Access (GKE)

Verify Workload Identity:
```bash
kubectl get serviceaccount -n observability observability-sa -o yaml
```

Test GCS access:
```bash
kubectl run -it --rm test-gcs \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- gcloud storage buckets list --filter="name:<PROJECT_ID>-"
```

Check IAM:
```bash
gcloud iam service-accounts get-iam-policy \
  gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

## Maintenance

### Upgrade

1. Update chart versions in `Chart.yaml`
2. Run `helm dependency update`
3. Test in staging
4. Upgrade:
   ```bash
   helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
     -f configs/monitoring-services/*.yaml
   ```

### Backup

**Grafana dashboards:**
```bash
kubectl exec -n observability deployment/monitoring-stack-grafana -- \
  grafana-cli admin export-dashboard > dashboards-backup.json
```

**Configuration:**
```bash
kubectl get configmap -n observability -o yaml > configmaps-backup.yaml
kubectl get secret -n observability -o yaml > secrets-backup.yaml
```

### Monitor the Stack

Add alerts in `prometheus-values.yaml`:
```yaml
prometheus:
  serverFiles:
    alerting_rules.yml:
      groups:
        - name: monitoring-stack
          rules:
            - alert: MonitoringPodDown
              expr: up{job=~"prometheus|loki|grafana"} == 0
              for: 5m
              annotations:
                summary: "Monitoring pod {{ $labels.job }} is down"
```

## Uninstallation

```bash
helm uninstall monitoring-stack -n observability
kubectl delete -f monitor-netbird/kubernetes/configs/cert-manager/monitoring-ingress.yaml
kubectl delete namespace observability
```

Warning: This permanently deletes all monitoring data.

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Mimir Documentation](https://grafana.com/docs/mimir/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Docker Compose Deployment](Monitoring-NetBird-Observability-Docker-Compose.md)
