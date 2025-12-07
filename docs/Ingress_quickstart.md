# Quick Start Guide

## Local Development (5 minutes)

### 1. Prerequisites Check

```bash
# Verify tools
kubectl version --client
helm version
kubectl cluster-info
```

### 2. Install All Components in monitoring Namespace

```bash
# Add all repos
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace monitoring \
  --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.service.type=NodePort

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace monitoring \
  --version v1.14.0 \
  --set installCRDs=true

# Wait for cert-manager
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n monitoring --timeout=120s
```

### 3. Configure Local DNS

```bash
# Get your node IP
NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[1].address}")

# Configure local DNS
sudo tee -a /etc/hosts << EOF
${NODE_IP} grafana.local prometheus.local loki.local mimir.local tempo.local
EOF
```

### 4. Configure Certificate Issuer

Edit `cert-manager-setup.yaml` and set your email, then apply: # For https

```bash
kubectl apply -f cert-manager-setup.yaml
kubectl get clusterissuer  # Should show READY=True
```

### 5. Deploy Monitoring Stack

```bash
# Deploy all components (order matters)
helm install monitoring-stack-prometheus prometheus-community/prometheus -f prometheus-values.yaml -n monitoring
helm install monitoring-stack-loki grafana/loki -f loki-values.yaml -n monitoring
helm install tempo grafana/tempo -f tempo-values.yaml -n monitoring
helm install monitoring-stack-mimir grafana/mimir-distributed -f mimir-values.yaml -n monitoring
helm install monitoring-stack-grafana grafana/grafana -f grafana-values.yaml -n monitoring

# Create ingress resources (required for most services)
kubectl create ingress grafana-ingress --class=nginx --rule="grafana.local/*=monitoring-stack-grafana:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress prometheus-ingress --class=nginx --rule="prometheus.local/*=monitoring-stack-prometheus-server:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress mimir-ingress --class=nginx --rule="mimir.local/*=monitoring-stack-mimir-gateway:80" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
kubectl create ingress tempo-ingress --class=nginx --rule="tempo.local/*=tempo:3200" -n monitoring --annotation=nginx.ingress.kubernetes.io/rewrite-target=/
```

### 6. Access

Wait 2-3 minutes, then access:
- **Grafana**: http://grafana.local (admin/admin)
- **Prometheus**: http://prometheus.local
- **Loki**: http://loki.local
- **Mimir**: http://mimir.local
- **Tempo**: http://tempo.local

---

## Production Deployment (15 minutes)

### 1. Prerequisites

- Valid domain name with DNS access
- Kubernetes cluster with LoadBalancer support

### 2. Get External IP

```bash
kubectl get svc -n monitoring nginx-ingress-ingress-nginx-controller
# Note the EXTERNAL-IP
```

### 3. Configure DNS

Create A records pointing to EXTERNAL-IP:
```
grafana.yourdomain.com
prometheus.yourdomain.com
loki.yourdomain.com
mimir.yourdomain.com
tempo.yourdomain.com
```

### 4. Update Certificate Issuer Email

Edit `cert-manager-setup.yaml`:
```yaml
email: your-email@yourdomain.com  # Change this
```

Apply:
```bash
kubectl apply -f cert-manager-setup.yaml
kubectl get clusterissuer  # Should show READY=True
```

### 5. Update Values Files

For each file (grafana, prometheus, loki, tempo, mimir):

**Comment out:**
```yaml
hosts:
  # - grafana.local
```

**Uncomment and edit:**
```yaml
hosts:
  - grafana.yourdomain.com  # Use your domain

tls:
  - secretName: grafana-tls
    hosts:
      - grafana.yourdomain.com

annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
```

### 6. Deploy/Upgrade Stack

```bash
# If not yet deployed, use install commands from local setup
# If already deployed, upgrade:
helm upgrade monitoring-stack-prometheus prometheus-community/prometheus -f prometheus-values.yaml -n monitoring
helm upgrade monitoring-stack-loki grafana/loki -f loki-values.yaml -n monitoring
helm upgrade tempo grafana/tempo -f tempo-values.yaml -n monitoring
helm upgrade monitoring-stack-mimir grafana/mimir-distributed -f mimir-values.yaml -n monitoring
helm upgrade monitoring-stack-grafana grafana/grafana -f grafana-values.yaml -n monitoring
```

### 7. Verify TLS

```bash
# Watch certificate creation (takes 2-5 minutes)
kubectl get certificate -n monitoring -w

# Should show Ready=True for all
```

### 8. Access

- **Grafana**: https://grafana.yourdomain.com
- **Prometheus**: https://prometheus.yourdomain.com
- **Loki**: https://loki.yourdomain.com
- **Mimir**: https://mimir.yourdomain.com
- **Tempo**: https://tempo.yourdomain.com

---

## Switching Environments

### Local → Production

1. Update DNS records to point to your cluster IP
2. Edit values files (comment local, uncomment production)
3. Run upgrade commands:
```bash
helm upgrade monitoring-stack-prometheus prometheus-community/prometheus -f prometheus-values.yaml -n monitoring
helm upgrade monitoring-stack-loki grafana/loki -f loki-values.yaml -n monitoring
helm upgrade tempo grafana/tempo -f tempo-values.yaml -n monitoring
helm upgrade monitoring-stack-mimir grafana/mimir-distributed -f mimir-values.yaml -n monitoring
helm upgrade monitoring-stack-grafana grafana/grafana -f grafana-values.yaml -n monitoring
```

### Production → Local

1. Edit values files (comment production, uncomment local)
2. Run same upgrade commands
3. Update `/etc/hosts`

---

## Common Commands

### Check Status

```bash
# All pods in monitoring namespace
kubectl get pods -n monitoring

# Specific service logs
kubectl logs -n monitoring deployment/monitoring-stack-grafana

# Ingress status
kubectl get ingress -n monitoring

# Certificates (production)
kubectl get certificate -n monitoring

# All resources
kubectl get all -n monitoring
```

### Restart Service

```bash
kubectl rollout restart deployment/monitoring-stack-grafana -n monitoring
```

### Uninstall Everything

```bash
# Remove all helm releases with proper cleanup
helm uninstall monitoring-stack-prometheus -n monitoring --wait
helm uninstall monitoring-stack-loki -n monitoring --wait
helm uninstall tempo -n monitoring --wait
helm uninstall monitoring-stack-mimir -n monitoring --wait
helm uninstall monitoring-stack-grafana -n monitoring --wait
helm uninstall cert-manager -n monitoring --wait
helm uninstall nginx-ingress -n monitoring --wait

# Clean remaining resources
kubectl delete all --all -n monitoring
kubectl delete pvc --all -n monitoring
kubectl delete ingress --all -n monitoring

# Remove namespace
kubectl delete namespace monitoring

# Remove ClusterIssuer (cluster-scoped resource)
kubectl delete clusterissuer letsencrypt-prod letsencrypt-staging
```

### Access Grafana Password

```bash
kubectl get secret -n monitoring monitoring-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

---

## Troubleshooting Quick Fixes

### Pods Pending

```bash
# Check PVC
kubectl get pvc -n monitoring

# If storage class missing, install default
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Ingress 404

```bash
# Check ingress controller
kubectl get pods -n monitoring | grep nginx

# Check ingress logs
kubectl logs -n monitoring deployment/nginx-ingress-ingress-nginx-controller
```

### Certificate Stuck

```bash
# Check certificate request
kubectl describe certificaterequest -n monitoring

# Check cert-manager logs
kubectl logs -n monitoring deployment/cert-manager

# Delete and recreate certificate
kubectl delete certificate grafana-tls -n monitoring
kubectl delete secret grafana-tls -n monitoring
helm upgrade monitoring-stack-grafana grafana/grafana -f grafana-values.yaml -n monitoring
```

### Can't Access Services

```bash
# Port forward as fallback
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80

# Access at http://localhost:3000
```

### Complete Reset

```bash
# Nuclear option - remove everything
kubectl delete namespace monitoring
kubectl delete clusterissuer letsencrypt-prod letsencrypt-staging

# Start fresh
kubectl create namespace monitoring
# Then redeploy from step 2
```

---

## Resource Requirements

**Minimum (Local/Dev):**
- 4 CPU cores
- 8GB RAM
- 20GB storage

**Production:**
- 8+ CPU cores
- 16GB+ RAM
- 50GB+ storage (adjust based on retention)

---

## Next Steps

1. Configure Grafana dashboards
2. Set up alerting rules
3. Configure log shipping to Loki
4. Instrument applications with Tempo tracing
5. Review security settings
6. Set up backups

See `DEPLOYMENT.md` for detailed documentation.