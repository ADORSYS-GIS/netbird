# NetBird Observability Stack on Kubernetes

Production-grade deployment guide for running Prometheus, Loki, Mimir, Tempo, and Grafana on Kubernetes with persistent storage and TLS ingress.

## Stack Components

- **Prometheus**: Metrics collection and short-term storage (7 days)
- **Loki**: Log aggregation with GCS backend (30 days)
- **Mimir**: Horizontally scalable long-term metrics storage (30 days)
- **Tempo**: Distributed tracing with GCS backend (30 days)
- **Grafana**: Unified visualization and dashboards

## Prerequisites

### Required Infrastructure
- Kubernetes cluster (K3s, EKS, GKE, or AKS)
- kubectl configured with cluster access
- Helm 3.x or later
- Sufficient storage for persistent volumes

### GKE-Specific Requirements
For GKE deployments, provision infrastructure first:
1. Complete the [Terraform Infrastructure Setup](../monitor-netbird/kubernetes/terraform/README.md)
2. Update Helm values files with GCS bucket names and service account
3. Ensure Workload Identity is enabled on your GKE cluster

### Optional Components
- cert-manager (required for TLS certificates)
- Ingress controller (NGINX or similar)
- external-dns (for automatic DNS management)

## Deployment

### Step 1: Create Namespaces

```bash
kubectl apply -f monitor-netbird/kubernetes/namespace.yaml
kubectl create namespace cert-manager
kubectl create namespace ingress-nginx
```

### Step 2: Add Helm Repositories

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 3: Install cert-manager (Optional but Recommended)

Required if you plan to use TLS certificates with Ingress.

**Install CRDs**:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml
```

**Install cert-manager**:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.15.0 \
  --set installCRDs=false
```

**Wait for cert-manager pods to be ready**:
```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s
```

**Apply ClusterIssuer**:
```bash
kubectl apply -f monitor-netbird/kubernetes/configs/cert-manager/cluster-issuer.yaml
```

### Step 4: Install Ingress Controller (Optional)

For production environments with external access requirements.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer
```

**Get Ingress external IP**:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Configure DNS A records pointing to this IP for your domain names.

### Step 5: Configure Helm Values

Edit the values files in `monitor-netbird/kubernetes/configs/monitoring-services/` to match your environment.

**Critical placeholders to replace**:

| Placeholder | Description | Location |
|-------------|-------------|----------|
| `<PROJECT_ID>` | GCP project ID | All GCS bucket references |
| `<GCP_SERVICE_ACCOUNT_EMAIL>` | Workload Identity SA email | Service account annotations (grafana-values.yaml , loki-values.yaml , mimir-values.yaml , prometheus-values.yaml , tempo-values.yaml) |
| `<GRAFANA_DOMAIN_NAME>` | Grafana domain | grafana-values.yaml, monitoring-ingress.yaml |
| `<LOKI_DOMAIN_NAME>` | Loki domain | loki-values.yaml, monitoring-ingress.yaml |
| `<YOUR_MONITORING_DOMAIN>` | Base monitoring domain | monitoring-ingress.yaml |
| `<LOKI_CHUNKS_BUCKET_NAME>` | Loki chunks bucket | loki-values.yaml |
| `<LOKI_RULER_BUCKET_NAME>` | Loki ruler bucket | loki-values.yaml |
| `<LOKI_ADMIN_BUCKET_NAME>` | Loki admin bucket | loki-values.yaml |
| `<MIMIR_BLOCKS_BUCKET_NAME>` | Mimir blocks bucket | mimir-values.yaml |
| `<MIMIR_RULER_BUCKET_NAME>` | Mimir ruler bucket | mimir-values.yaml |
| `<MIMIR_ALERTMANAGER_BUCKET_NAME>` | Mimir alertmanager bucket | mimir-values.yaml |
| `<TEMPO_TRACES_BUCKET_NAME>` | Tempo traces bucket | tempo-values.yaml |
| `<CLUSTER_NAME>` | Kubernetes cluster name | prometheus-values.yaml , values.yaml |
| `<ENVIRONMENT>` | Deployment environment | prometheus-values.yaml , values.yaml |
| `<YOUR_EMAIL_ADDRESS>` | Email for Let's Encrypt | cluster-issuer.yaml |

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

### Step 7: Apply Ingress and NodePort Resources

**For TLS-enabled Ingress** (requires cert-manager):
```bash
kubectl apply -f monitor-netbird/kubernetes/configs/cert-manager/monitoring-ingress.yaml
```

**For NodePort access** (development/testing):
```bash
kubectl apply -f monitor-netbird/kubernetes/configs/monitoring-services/loki-nodeport-service.yaml
kubectl apply -f monitor-netbird/kubernetes/configs/monitoring-services/tempo-nodeport-service.yaml
```

### Step 8: Verify Deployment

```bash
kubectl get pods -n observability
kubectl get svc -n observability
kubectl get ingress -n observability
```

All pods should reach `Running` status within 5 minutes.

**Check pod logs if issues occur**:
```bash
kubectl logs -n observability <pod-name> --tail=50
```

## Access and Configuration

### Access Grafana

**Via Ingress** (production):
```
https://<GRAFANA_DOMAIN_NAME>
```

**Via NodePort** (development):
```
http://<NODE_IP>:30300
```

**Default credentials**: `admin` / `admin`

**Security Warning**: Change the default password immediately after first login.

### Configure Data Sources

Data sources are pre-configured in `grafana-values.yaml` but should be verified:

1. Navigate to **Connections** → **Data sources**
2. Verify each data source:
   - **Prometheus**: `http://monitoring-stack-prometheus-server:80`
   - **Loki**: `http://monitoring-stack-loki-gateway:80`
   - **Mimir**: `http://monitoring-stack-mimir-nginx:80/prometheus`
   - **Tempo**: `http://tempo-external:3200`
3. Click **Save & test** for each to verify connectivity

### Service Endpoints

| Service | Internal URL | NodePort | Ingress |
|---------|--------------|----------|---------|
| Grafana | `monitoring-stack-grafana:80` | 30300 | Yes |
| Prometheus | `monitoring-stack-prometheus-server:80` | 30090 | Yes |
| Loki | `monitoring-stack-loki-gateway:80` | 31100 | Yes |
| Mimir | `monitoring-stack-mimir-nginx:80` | 30080 | Yes |
| Tempo | `tempo-external:3200` | 31200 | Yes |

## Data Collection

### Metrics Collection

Prometheus automatically scrapes:
- Kubernetes cluster components (API server, nodes, cAdvisor)
- kube-state-metrics
- Monitoring stack components (configured in prometheus-values.yaml)

**Pre-configured scrape targets** in `prometheus-values.yaml`:
- Loki: `monitoring-stack-loki-gateway:80`
- Grafana: `monitoring-stack-grafana:80`
- Mimir Distributor: `monitoring-stack-mimir-distributor:8080`
- Tempo: `monitoring-stack-tempo:3200`

**View active targets**:
```
http://<PROMETHEUS_DOMAIN>/targets
```

**Add custom scrape targets** by editing `prometheus-values.yaml`:
```yaml
prometheus:
  extraScrapeConfigs: |
    - job_name: 'my-application'
      static_configs:
        - targets: ['my-app-service:8080']
          labels:
            environment: 'production'
```

Then upgrade the deployment:
```bash
helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
  -f configs/monitoring-services/prometheus-values.yaml \
  -f configs/monitoring-services/loki-values.yaml \
  -f configs/monitoring-services/grafana-values.yaml \
  -f configs/monitoring-services/mimir-values.yaml \
  -f configs/monitoring-services/tempo-values.yaml
```

### Log Collection

**Using Promtail** (DaemonSet for cluster-wide log collection):
```bash
helm install promtail grafana/promtail -n observability \
  --set "loki.serviceName=monitoring-stack-loki-gateway"
```

**Direct log ingestion endpoint**:
```
POST http://monitoring-stack-loki-gateway:80/loki/api/v1/push
```

**Example using Docker logging driver**:
```yaml
logging:
  driver: loki
  options:
    loki-url: "http://<LOKI_DOMAIN>:31100/loki/api/v1/push"
    labels: "app,environment"
```

### Trace Collection

Configure applications to send traces to Tempo using the following endpoints:

**OTLP endpoints** (via tempo-external service):
- gRPC: `tempo-external:4317` (NodePort: 31317)
- HTTP: `tempo-external:4318` (NodePort: 31318)

**Jaeger endpoints**:
- Thrift HTTP: `tempo-external:14268` (NodePort: 31268)

**Additional supported protocols** (via monitoring-stack-tempo service):
- Jaeger gRPC: Port 14250
- Jaeger Thrift Binary: Port 6832
- Jaeger Thrift Compact: Port 6831
- Zipkin: Port 9411
- OpenCensus: Port 55678

**Example OpenTelemetry configuration**:
```yaml
exporters:
  otlp:
    endpoint: "tempo-external:4317"
    tls:
      insecure: true
```

## Querying Data

### Prometheus Queries

Navigate to **Explore** and select **Prometheus**.

**Example queries**:
```promql
# Cluster CPU usage by node
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total

# Monitoring stack health
up{job=~"prometheus|loki|grafana|mimir.*|tempo"}

# Loki ingestion rate
rate(loki_ingester_chunks_created_total[5m])

# Mimir active series
cortex_ingester_active_series
```

### Loki Queries

Select **Loki** data source in **Explore**.

**Example queries**:
```logql
# All logs from observability namespace
{namespace="observability"}

# Error logs
{namespace="observability"} |= "error"

# Log rate per second
rate({namespace="observability"}[1m])

# Logs from specific pod
{namespace="observability", pod=~"loki.*"}

# Parse JSON logs
{namespace="observability"} | json | level="error"
```

### Tempo Queries

Select **Tempo** data source in **Explore**.

Use the search interface to filter by:
- Service name
- Span duration
- Status (error/success)
- Tags

Or query by trace ID directly:
```
<trace-id>
```

## Storage and Retention

### Retention Configuration

| Component | Retention | Configuration File |
|-----------|-----------|-------------------|
| Prometheus | 7 days | prometheus-values.yaml |
| Loki | 30 days (720h) | loki-values.yaml |
| Mimir | 30 days (720h) | mimir-values.yaml |
| Tempo | 30 days (720h) | tempo-values.yaml |

### Modify Retention

Edit the respective values file and upgrade the Helm release:

**Prometheus retention** (in prometheus-values.yaml):
```yaml
prometheus:
  server:
    retention: 7d
```

**Loki retention** (in loki-values.yaml):
```yaml
loki:
  loki:
    limits_config:
      retention_period: 720h
```

**Mimir retention** (in mimir-values.yaml):
```yaml
mimir-distributed:
  mimir:
    structuredConfig:
      blocks_storage:
        tsdb:
          retention_period: 720h
```

**Tempo retention** (in tempo-values.yaml):
```yaml
tempo:
  tempo:
    compactor:
      compaction:
        block_retention: 720h
```

Then upgrade:
```bash
helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
  -f configs/monitoring-services/loki-values.yaml \
  -f configs/monitoring-services/prometheus-values.yaml \
  -f configs/monitoring-services/grafana-values.yaml \
  -f configs/monitoring-services/mimir-values.yaml \
  -f configs/monitoring-services/tempo-values.yaml
```

### Persistent Volume Configuration

Each component uses persistent storage:

| Component | Default Size | Storage Class |
|-----------|-------------|---------------|
| Prometheus | 3Gi | Cluster default |
| Loki | 5Gi | standard-rwo |
| Mimir (Ingester) | 3Gi | Cluster default |
| Mimir (Store Gateway) | 3Gi | Cluster default |
| Mimir (Compactor) | 3Gi | Cluster default |
| Tempo | 3Gi | Cluster default |
| Grafana | 1Gi | Cluster default |

Verify persistent volumes:
```bash
kubectl get pv
kubectl get pvc -n observability
```

## Production Hardening

### Security

**Immediate actions**:
- Change default Grafana password
- Enable TLS for all external endpoints
- Configure authentication (OAuth, LDAP, SAML)

**Ongoing measures**:
- Implement RBAC policies
- Use Kubernetes secrets for credentials
- Apply network policies
- Regular security updates

**Example NetworkPolicy** for observability namespace:
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

**Increase replicas** for critical components in values files:

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

# tempo-values.yaml
tempo:
  replicas: 3
```

**Configure pod anti-affinity** to distribute pods across nodes:
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - loki
          topologyKey: kubernetes.io/hostname
```

**Example PodDisruptionBudget**:
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

**Set resource requests and limits** in values files:
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

**Monitor resource usage**:
```bash
kubectl top pods -n observability
kubectl top nodes
```

## Troubleshooting

### Pod Startup Issues

**Check pod status**:
```bash
kubectl describe pod -n observability <pod-name>
kubectl logs -n observability <pod-name> --previous
```

**Common causes**:
- Insufficient node resources
- Storage provisioning failures
- Image pull errors
- Configuration errors in values files

### Data Source Connection Failures

1. Verify pods are healthy:
   ```bash
   kubectl get pods -n observability
   ```

2. Check service endpoints:
   ```bash
   kubectl get endpoints -n observability
   ```

3. Test internal connectivity:
   ```bash
   kubectl run -n observability test-pod --rm -it \
     --image=curlimages/curl -- sh
   # Inside pod:
   curl http://monitoring-stack-prometheus-server:80/-/healthy
   curl http://monitoring-stack-loki-gateway:80/ready
   curl http://monitoring-stack-mimir-nginx:80/ready
   curl http://tempo-external:3200/ready
   ```

### Ingress Issues

**Check Ingress status**:
```bash
kubectl describe ingress -n observability monitoring-stack-ingress
```

**Verify certificate provisioning**:
```bash
kubectl get certificate -n observability
kubectl describe certificate -n observability monitoring-tls
```

**Check cert-manager logs**:
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

**Common issues**:
- DNS not pointing to Ingress IP
- ClusterIssuer not ready
- Rate limiting from Let's Encrypt (use letsencrypt-staging for testing)

### Storage Issues

**Check persistent volumes**:
```bash
kubectl get pv
kubectl get pvc -n observability
kubectl describe pvc -n observability <pvc-name>
```

**Common issues**:
- Storage class not available
- Insufficient cluster storage capacity
- PVC pending due to node affinity constraints

### GCS Access Issues (GKE)

**Verify Workload Identity annotation**:
```bash
kubectl get serviceaccount -n observability observability-sa -o yaml
```

Expected annotation:
```yaml
iam.gke.io/gcp-service-account: gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

**Test GCS access**:
```bash
kubectl run -it --rm test-gcs \
  --image=google/cloud-sdk:slim \
  --serviceaccount=observability-sa \
  --namespace=observability \
  -- gcloud storage buckets list --filter="name:<PROJECT_ID>-"
```

**Check IAM policies**:
```bash
gcloud iam service-accounts get-iam-policy \
  gke-observability-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

### Loki Specific Issues

**Check Loki readiness**:
```bash
kubectl logs -n observability -l app.kubernetes.io/name=loki --tail=100
```

**Common issues**:
- GCS bucket access denied
- Insufficient retention settings causing data loss
- Schema version mismatch

### Mimir Specific Issues

**Check Mimir components**:
```bash
kubectl logs -n observability -l app.kubernetes.io/name=mimir-distributed --tail=100
```

**Verify remote write from Prometheus**:
```bash
kubectl logs -n observability -l app.kubernetes.io/name=prometheus --tail=50 | grep -i mimir
```

## Maintenance

### Upgrade Procedure

1. Update chart versions in `Chart.yaml`
2. Run `helm dependency update`
3. Review release notes for breaking changes
4. Test in staging environment
5. Perform upgrade:
   ```bash
   helm upgrade monitoring-stack ./helm/monitoring-stack -n observability \
     -f configs/monitoring-services/loki-values.yaml \
     -f configs/monitoring-services/prometheus-values.yaml \
     -f configs/monitoring-services/grafana-values.yaml \
     -f configs/monitoring-services/mimir-values.yaml \
     -f configs/monitoring-services/tempo-values.yaml
   ```

### Backup Procedures

**Grafana dashboards**:
```bash
kubectl exec -n observability deployment/monitoring-stack-grafana -- \
  grafana-cli admin export-dashboard > dashboards-backup.json
```

**Prometheus data snapshot**:
```bash
kubectl cp observability/<prometheus-pod>:/data ./prometheus-backup
```

**Configuration backup**:
```bash
kubectl get configmap -n observability -o yaml > configmaps-backup.yaml
kubectl get secret -n observability -o yaml > secrets-backup.yaml
```

### Monitoring the Monitoring Stack

**Create alerts** by adding to `prometheus-values.yaml`:
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
            
            - alert: HighMemoryUsage
              expr: container_memory_usage_bytes{namespace="observability"} / container_spec_memory_limit_bytes{namespace="observability"} > 0.9
              for: 5m
              annotations:
                summary: "High memory usage in {{ $labels.pod }}"
```

## Uninstallation

**Remove Helm release**:
```bash
helm uninstall monitoring-stack -n observability
```

**Delete additional resources**:
```bash
kubectl delete -f monitor-netbird/kubernetes/configs/monitoring-services/loki-nodeport-service.yaml
kubectl delete -f monitor-netbird/kubernetes/configs/monitoring-services/tempo-nodeport-service.yaml
kubectl delete -f monitor-netbird/kubernetes/configs/cert-manager/monitoring-ingress.yaml
```

**Delete namespace** (removes all resources and PVCs):
```bash
kubectl delete namespace observability
```

**Warning**: This permanently deletes all monitoring data. Back up critical data before proceeding.

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Mimir Documentation](https://grafana.com/docs/mimir/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Compose Deployment](Monitoring-NetBird-Observability-Docker-Compose.md)