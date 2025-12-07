# Monitoring Stack Deployment Guide

Complete production-ready monitoring stack with Prometheus, Grafana, Loki, Tempo, and Mimir on Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Local Development Setup](#local-development-setup)
- [Production Deployment](#production-deployment)
- [Switching Between Environments](#switching-between-environments)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- Kubernetes cluster (v1.24+)
- kubectl configured
- Helm 3.x installed

### Local Development Only

- `/etc/hosts` write access for local DNS resolution

### Production Only

- Valid domain names
- DNS access to create A/CNAME records

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Nginx Ingress                         │
│  (TLS termination, routing, load balancing)             │
└────────────┬────────────────────────────────────────────┘
             │
     ┌───────┴────────┐
     │                │
┌────▼─────┐    ┌────▼─────┐
│ Grafana  │    │Prometheus│
│  :3000   │    │  :9090   │
└────┬─────┘    └────┬─────┘
     │               │
     │         ┌─────┴──────┬─────────┐
     │         │            │         │
┌────▼─────┐ ┌▼──────┐ ┌──▼─────┐ ┌─▼──────┐
│   Loki   │ │ Tempo │ │ Mimir  │ │ Kube   │
│  :3100   │ │ :3200 │ │ :8080  │ │ State  │
└──────────┘ └───────┘ └────────┘ └────────┘
```

**Components:**
- **Prometheus**: Metrics collection and short-term storage
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing
- **Mimir**: Long-term metrics storage

## Local Development Setup

### 1. Install nginx-ingress-controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace monitoring \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.hostPort.enabled=true \
  --set controller.admissionWebhooks.enabled=false
```

### 2. Configure Local DNS

```bash
# Get your node IP
NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[1].address}")

# Add to /etc/hosts
sudo tee -a /etc/hosts << EOF
# Monitoring Stack - Local
${NODE_IP} grafana.local
${NODE_IP} prometheus.local
${NODE_IP} loki.local
${NODE_IP} mimir.local
${NODE_IP} tempo.local
EOF
```

### 3. Deploy Monitoring Stack

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Deploy cert-manager (for both local and production)
helm install cert-manager jetstack/cert-manager \
  --namespace monitoring \
  --version v1.14.0 \
  --set installCRDs=true

# Wait for cert-manager
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n monitoring --timeout=120s

# Apply ClusterIssuer
kubectl apply -f cert-manager-setup.yaml

# Deploy monitoring components
helm install monitoring-stack-prometheus prometheus-community/prometheus \
  -f prometheus-values.yaml \
  -n monitoring

helm install monitoring-stack-loki grafana/loki \
  -f loki-values.yaml \
  -n monitoring

helm install tempo grafana/tempo \
  -f tempo-values.yaml \
  -n monitoring

helm install monitoring-stack-mimir grafana/mimir-distributed \
  -f mimir-values.yaml \
  -n monitoring

helm install monitoring-stack-grafana grafana/grafana \
  -f grafana-values.yaml \
  -n monitoring

# Create ingress resources (required for most services)
kubectl create ingress grafana-ingress --class=nginx --rule="grafana.local/*=monitoring-stack-grafana:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress prometheus-ingress --class=nginx --rule="prometheus.local/*=monitoring-stack-prometheus-server:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress mimir-ingress --class=nginx --rule="mimir.local/*=monitoring-stack-mimir-gateway:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress tempo-ingress --class=nginx --rule="tempo.local/*=tempo:3200" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
```

### 4. Access Services

- Grafana: http://grafana.local
- Prometheus: http://prometheus.local
- Loki: http://loki.local
- Mimir: http://mimir.local
- Tempo: http://tempo.local

**Default Credentials:**
- Username: `admin`
- Password: `admin`

## Production Deployment

### 1. Configure ClusterIssuer

Edit `cert-manager-setup.yaml` and change email:

```yaml
email: admin@yourdomain.com  # Your actual email
```

Apply:

```bash
kubectl apply -f cert-manager-setup.yaml
```

Verify:

```bash
kubectl get clusterissuer
# Should show: letsencrypt-prod READY=True
```

### 2. Configure DNS

Create DNS A records pointing to your cluster's external IP:

```bash
# Get LoadBalancer IP
kubectl get svc -n monitoring nginx-ingress-ingress-nginx-controller
```

Create DNS records:
```
grafana.yourdomain.com    → <EXTERNAL-IP>
prometheus.yourdomain.com → <EXTERNAL-IP>
loki.yourdomain.com       → <EXTERNAL-IP>
mimir.yourdomain.com      → <EXTERNAL-IP>
tempo.yourdomain.com      → <EXTERNAL-IP>
```

### 3. Update Values Files

In each `*-values.yaml` file, uncomment production sections:

#### Example for grafana-values.yaml:

**Find and comment out:**
```yaml
hosts:
  # - grafana.local  # Comment this out
```

**Uncomment production config:**
```yaml
hosts:
  - grafana.yourdomain.com  # Uncomment and set your domain

# Uncomment TLS section:
tls:
  - secretName: grafana-tls
    hosts:
      - grafana.yourdomain.com

# Uncomment annotations:
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
```

**Repeat for all services** (prometheus, loki, tempo, mimir).

### 4. Deploy with Production Config

```bash
# Upgrade existing deployments with production values
helm upgrade monitoring-stack-prometheus prometheus-community/prometheus \
  -f prometheus-values.yaml -n monitoring

helm upgrade monitoring-stack-loki grafana/loki \
  -f loki-values.yaml -n monitoring

helm upgrade tempo grafana/tempo \
  -f tempo-values.yaml -n monitoring

helm upgrade monitoring-stack-mimir grafana/mimir-distributed \
  -f mimir-values.yaml -n monitoring

helm upgrade monitoring-stack-grafana grafana/grafana \
  -f grafana-values.yaml -n monitoring
```

### 5. Verify TLS Certificates

```bash
# Check certificate requests
kubectl get certificaterequest -n monitoring

# Check certificates
kubectl get certificate -n monitoring

# Check secrets
kubectl get secret -n monitoring | grep tls
```

Wait 2-5 minutes for Let's Encrypt to issue certificates.

### 6. Access Production Services

- Grafana: https://grafana.yourdomain.com
- Prometheus: https://prometheus.yourdomain.com
- Loki: https://loki.yourdomain.com
- Mimir: https://mimir.yourdomain.com
- Tempo: https://tempo.yourdomain.com

## Switching Between Environments

### Local → Production

1. Update DNS records
2. Edit values files: uncomment production sections, comment local sections
3. Run helm upgrade commands
4. Wait for TLS provisioning

### Production → Local

1. Edit values files: uncomment local sections, comment production sections
2. Run helm upgrade commands
3. Update `/etc/hosts`

## Verification

### Check Pod Status

```bash
kubectl get pods -n monitoring
```

All pods should be `Running`.

### Check Ingress

```bash
kubectl get ingress -n monitoring
```

Should show all services with configured hosts.

### Check Certificates (Production)

```bash
kubectl get certificate -n monitoring
```

Status should be `Ready=True`.

### Test Endpoints

```bash
# Local
curl -k http://grafana.local
curl -k http://prometheus.local

# Production
curl https://grafana.yourdomain.com
curl https://prometheus.yourdomain.com
```

### Grafana Data Sources

1. Login to Grafana
2. Navigate to: Configuration → Data Sources
3. Verify all sources are green (Prometheus, Loki, Mimir, Tempo)

## Troubleshooting

### Pods Not Starting

```bash
# Check pod logs
kubectl logs -n monitoring <pod-name>

# Check events
kubectl describe pod -n monitoring <pod-name>
```

**Common issues:**
- Persistent volume claims pending → Check storage class
- Image pull errors → Check network/registry access
- OOMKilled → Increase resource limits

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n monitoring

# Check ingress logs
kubectl logs -n monitoring <nginx-ingress-pod>

# Check ingress config
kubectl describe ingress -n monitoring <ingress-name>
```

### Certificate Issues (Production)

```bash
# Check certificate status
kubectl describe certificate -n monitoring grafana-tls

# Check certificate request
kubectl describe certificaterequest -n monitoring

# Check cert-manager logs
kubectl logs -n monitoring deployment/cert-manager
```

**Common certificate errors:**

1. **Pending state**: DNS not propagated, wait 5-10 minutes
2. **Rate limited**: Use staging issuer first, or wait 1 hour
3. **Validation failed**: Check DNS A records point to correct IP
4. **Firewall**: Ensure port 80 accessible for HTTP-01 challenge

### DNS Resolution Issues

**Local:**
```bash
# Test DNS
ping grafana.local

# If fails, check /etc/hosts
cat /etc/hosts | grep grafana
```

**Production:**
```bash
# Test DNS propagation
nslookup grafana.yourdomain.com
dig grafana.yourdomain.com

# Test HTTP-01 challenge path
curl http://grafana.yourdomain.com/.well-known/acme-challenge/test
```

### Data Source Connection Issues

1. Check service endpoints:
```bash
kubectl get svc -n monitoring
```

2. Test internal connectivity:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n monitoring -- sh
# Inside pod:
curl http://monitoring-stack-prometheus-server:80
curl http://monitoring-stack-loki-gateway:80
```

3. Check Grafana logs:
```bash
kubectl logs -n monitoring deployment/monitoring-stack-grafana
```

### Resource Exhaustion

```bash
# Check resource usage
kubectl top pods -n monitoring
kubectl top nodes

# Check persistent volume usage
kubectl get pvc -n monitoring
```

If resources insufficient, uncomment and adjust resource limits in values files.

## Production Best Practices

### Security

1. **Change default passwords**:
```yaml
grafana:
  adminPassword: "<use-strong-password>"
  # Better: Use external secret manager
```

2. **Enable authentication** on all services via ingress annotations:
```yaml
nginx.ingress.kubernetes.io/auth-type: basic
nginx.ingress.kubernetes.io/auth-secret: basic-auth
```

3. **Use NetworkPolicies** to restrict pod communication

### High Availability

For production HA:

1. Increase replicas:
```yaml
replicas: 3
```

2. Enable zone-aware replication:
```yaml
zoneAwareReplication:
  enabled: true
```

3. Use object storage (S3, GCS, Azure):
```yaml
storage:
  backend: s3
  s3:
    bucket: your-bucket
    region: us-east-1
```

### Monitoring the Monitoring Stack

1. Enable Prometheus scraping of all components
2. Set up alerts for pod failures
3. Monitor certificate expiration
4. Track storage usage

### Backup Strategy

1. **PVC backups**: Use Velero or cloud-native backup solutions
2. **Grafana dashboards**: Export regularly or use provisioning
3. **Prometheus data**: Configure remote write to Mimir
4. **Loki logs**: Set appropriate retention periods

### Cost Optimization

1. Adjust retention periods based on requirements
2. Use lifecycle policies for object storage
3. Right-size resource requests/limits
4. Enable compaction for efficient storage

## Reference

### Helm Chart Versions

- prometheus: 25.x
- grafana: 8.x
- loki: 6.x
- tempo: 1.x
- mimir-distributed: 5.x

### Port Reference

| Service    | Internal Port | Service Port | Ingress |
|------------|---------------|--------------|---------|
| Grafana    | 3000          | 80           | 80/443  |
| Prometheus | 9090          | 80           | 80/443  |
| Loki       | 3100          | 80           | 80/443  |
| Tempo      | 3200          | 3200         | 80/443  |
| Mimir      | 8080          | 80           | 80/443  |

### Storage Requirements (Single Node)

- Prometheus: 3Gi
- Loki: 3Gi
- Tempo: 3Gi
- Mimir Ingester: 3Gi
- Mimir Store Gateway: 3Gi
- Mimir Compactor: 3Gi
- Grafana: 1Gi

**Total**: ~19Gi

For production, scale based on data volume and retention period.

## Support

For issues specific to:
- **Prometheus**: https://github.com/prometheus-community/helm-charts
- **Grafana**: https://github.com/grafana/helm-charts
- **Loki**: https://grafana.com/docs/loki/
- **Tempo**: https://grafana.com/docs/tempo/
- **Mimir**: https://grafana.com/docs/mimir/
- **cert-manager**: https://cert-manager.io/docs/