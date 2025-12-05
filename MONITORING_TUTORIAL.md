# MONITORING STACK DEPLOYMENT

This is a comprehensive, step-by-step tutorial designed to take you from zero to a fully functioning, secure Observability Stack (Grafana, Loki, Mimir, Tempo) on Google Kubernetes Engine (GKE).

This tutorial assumes:
- You have a Google Cloud Project (ID: `observe-472521`).
- You want public, secure URLs (HTTPS) for everything.
- You want to simulate a real-world scenario where an external agent ("Alloy") sends data to your cluster.

## Phase 1: Preparation & Infrastructure

### 1. Prerequisites
Install these tools on your local machine:
- Google Cloud CLI (`gcloud`)
- Kubectl (Kubernetes command line)
- Helm (Package manager for Kubernetes)

### 2. Login and Set Project
Run these commands in your terminal:
```bash
gcloud auth login
gcloud config set project observe-472521
```

### 3. Create the GKE Cluster
We need a cluster with enough resources. Mimir and Loki can be memory-hungry.

Wait for this to finish (approx 5-10 mins).

Get credentials to access the cluster:
```bash
gcloud container clusters get-credentials grafana-stack --region us-central1
```

## Phase 2: The Security Layer (Ingress & Auth)

We will use an Ingress Controller to give us a public IP and Basic Authentication to secure the endpoints so not just anyone can push data.

### 1. Install Nginx Ingress
This handles incoming traffic.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

**Wait for the Public IP:**
Run the following command until you see an EXTERNAL-IP (e.g., `34.x.x.x`):

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

> **Note**: Write down this IP. For this tutorial, we will use `nip.io` to simulate a DNS domain.
> Your Domain will be: `observe.<YOUR_IP>.nip.io`

### 2. Create Authentication Credentials
We don't want the internet writing to your database. We will create a username (`agent`) and password (`securepass`) for your Alloy collectors.

Create an `htpasswd` file locally:
(If you don't have `htpasswd` installed, use an online generator to get the hash, or install `apache2-utils`)

```bash
# Create a username 'admin' with password 'password123'
htpasswd -c auth admin
# (Type password123)

# Create a generic secret in Kubernetes
kubectl create secret generic basic-auth \
  --namespace monitoring \
  --from-file=auth
```

## Phase 3: Deploying the Stack (Helm)

We will use the Kube Prometheus Stack (for Prometheus/Grafana) and separate charts for Loki, Tempo, and Mimir.

First, add the Grafana repo:
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 1. Create a "All-in-One" Values File
Create the following files. This tells Helm how to configure everything. Replace `YOUR_IP` with the IP you got in Phase 2.

**prometheus-values.yml**:
```yaml
# prometheus-values.yaml - Complete configuration with NodePort

grafana:
  enabled: false

prometheus:
  prometheusSpec:
    # External labels
    externalLabels:
      cluster: "dev-k8s" 
      prom_instance: "primary-kube-p"

    # Remote write to Mimir
    remoteWrite:
      - url: "http://observe-mimir-gateway:8080/api/v1/push"
        headers:
          "X-Scope-OrgID": "default"
        queueConfig:
          capacity: 10000 
          maxShards: 100 
          maxSamplesPerSend: 2000

    # Scrape configs
    serviceMonitorSelectorNilUsesHelmValues: false

    # Storage
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

  # Expose Prometheus with NodePort
  service:
    type: NodePort
    nodePort: 32090

alertmanager:
  enabled: true
  
  alertmanagerSpec:
    service:
      type: NodePort
      nodePort: 32091

prometheus-operator:
  enabled: true

prometheus-node-exporter:
  enabled: true

kube-state-metrics:
  enabled: true
```

**loki-values.yml**:
```yaml
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  
  commonConfig:
    replication_factor: 1

  # Disable memberlist for SingleBinary
  memberlist:
    enabled: false

  schemaConfig:
    configs:
      - from: 2025-11-04
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h

  storage:
    type: filesystem

  # --- FIX 1: Update paths to use /var/loki (The Writable Volume) ---
  structuredConfig:
    storage_config:
      tsdb_shipper:
        active_index_directory: /var/loki/tsdb-index
        cache_location: /var/loki/tsdb-cache
      filesystem:
        directory: /var/loki/chunks
    
    # Simple limits to prevent OOM
    limits_config:
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 15

# --- FIX 2: Disable unnecessary caching pods ---
chunksCache:
  enabled: false
resultsCache:
  enabled: false

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    emptyDir: {}  # Keeps it ephemeral (use PVC logic if you need real persistence)

# Disable microservice components
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
gateway:
  enabled: false
```

**mimir-values.yml**:
```yaml
deploymentMode: SimpleScalable

mimir:
  structuredConfig:
    target: all

    distributor:
      ring:
        kvstore:
          store: inmemory

    ingester:
      ring:
        kvstore:
          store: inmemory
        replication_factor: 1

    querier:
      max_concurrent: 20

    ruler:
      enable_api: true
      rule_path: /data/mimir/rules

    blocks_storage:
      backend: filesystem
      filesystem:
        dir: /data/mimir/blocks

    compactor:
      data_dir: /data/mimir/compactor
      sharding_ring:
        kvstore:
          store: inmemory

    store_gateway:
      sharding_ring:
        kvstore:
          store: inmemory

ingester:
  zoneAwareReplication:
    enabled: false

persistence:
  enabled: true
  storageClassName: local-path
  size: 20Gi
  mountPath: /data

# Gateway configuration
gateway:
  enabled: true
  replicas: 1
  service:
    type: NodePort
    nodePort: 32080
    port: 8080

# Resource limits
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

**tempo-values.yml**:
```yaml
# tempo-values.yaml

fullnameOverride: observe-tempo

tempo:
  repository: grafana/tempo
  tag: 2.9.0
  
  # Configure storage to use local filesystem (like your Loki config)
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces
      wal:
        path: /var/tempo/wal

  # Disable the metrics generator to clean up those log warnings if not needed
  metricsGenerator:
    enabled: false

# Enable persistence so traces survive pod restarts
persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  # Use emptyDir for ephemeral testing, or remove this line to use a PVC
  # emptyDir: {} 

service:
  type: NodePort
  # Define the NodePorts explicitly
  nodePorts:
    grpc-otlp: 32002  # OTLP gRPC (Port 4317 internally)
    http: 32005       # Tempo Query HTTP (Port 3200 internally)

  # Explicitly define ports to ensure targets are correct
  ports:
    - name: grpc-otlp
      port: 4317
      protocol: TCP
      targetPort: 4317
      nodePort: 32002
    - name: http
      port: 3200        # Corrected from 3100 to 3200
      protocol: TCP
      targetPort: 3200
      nodePort: 32005
    - name: otlp-http
      port: 4318
      protocol: TCP
      targetPort: 4318
```

### 2. Deploy the Components

**Deploy Prometheus & Grafana:**
```bash
helm install kube-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yml
```

**Deploy Loki (Logs):**
```bash
helm install loki grafana/loki \
  --namespace monitoring \
  -f loki-values.yml
```

**Deploy Tempo (Traces):**
```bash
helm install tempo grafana/tempo \
  --namespace monitoring \
  -f tempo-values.yml
```

**Deploy Mimir (Metrics Long-term):**
```bash
helm install mimir grafana/mimir-distributed \
  --namespace monitoring \
  -f mimir-values.yml
```

## Phase 4: Configure External Alloy (The Collector)

Now you have a GKE cluster waiting for data. Let's configure an external Alloy (running on your laptop or another server) to send data to it.

Create a file `alloy-config.alloy` on your local machine:

```hcl
// alloy-config.alloy

// 1. Receive data (simulated for this tutorial)
prometheus.scrape "self_scrape" {
  targets = [{"__address__" = "localhost:12345"}] // Just scraping Alloy itself
  forward_to = [prometheus.remote_write.gke_mimir.receiver]
}

logging {
  level  = "info"
  format = "logfmt"
}

// 2. Send Metrics to Mimir on GKE
prometheus.remote_write "gke_mimir" {
  endpoint {
    url = "http://mimir.YOUR_IP.nip.io/api/v1/push"
    basic_auth {
      username = "admin"
      password = "password123"
    }
  }
}

// 3. Send Logs to Loki on GKE
loki.write "gke_loki" {
  endpoint {
    url = "http://loki.YOUR_IP.nip.io/loki/api/v1/push"
    basic_auth {
      username = "admin"
      password = "password123"
    }
  }
}

// 4. Generate fake logs to test connection
loki.source.file "local_files" {
  targets    = [{"__path__" = "/var/log/*.log"}] 
  forward_to = [loki.write.gke_loki.receiver]
}
```

Run Alloy locally pointing to this config. It will now securely push data over the internet to your GKE cluster using the credentials we set up.

## Phase 5: Verification & Usage

### Access Grafana
Open `http://grafana.YOUR_IP.nip.io` in your browser.
Default login is usually `admin` / `prom-operator`.
(Get the actual password via: `kubectl get secret -n monitoring kube-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode`)

### Add Data Sources
Go to **Configuration -> Data Sources**.
- **Loki**: URL = `http://loki:3100` (Internal Cluster URL)
- **Mimir**: URL = `http://mimir-nginx:80` (Internal Cluster URL)
- **Tempo**: URL = `http://tempo:3100` (Internal Cluster URL)

### Check Data
Go to **Explore**.
- Select **Loki**. You should see logs arriving from your external Alloy.
- Select **Prometheus** (or Mimir). You should see metrics.

## Troubleshooting Guide

### 1. "I can't access the URLs"
- **Check the Ingress IP**: Run `kubectl get ingress -n monitoring`. Ensure they all share the same IP address.
- **Check DNS**: Try `ping loki.YOUR_IP.nip.io`. It should resolve to the external IP.
- **Check Ingress Controller**: `kubectl get pods -n ingress-nginx`. Are they running?

### 2. "Alloy says 401 Unauthorized"
This means your Basic Auth is working, but your password in `alloy.config` is wrong.
Double-check the `htpasswd` file generation and the `kubectl create secret` step in Phase 2.

### 3. "Mimir/Loki Pods are Pending"
These apps need storage (Persistent Volumes).
- Run `kubectl get pvc -n monitoring`. If they are "Pending", GKE might be out of resources or quota.
- Run `kubectl describe pod <pod-name> -n monitoring` to see the exact error (usually "Insufficient CPU" or "Unbound PVC").

### 4. "Grafana says Bad Gateway (502) for Data Sources"
When configuring Data Sources inside Grafana, use the internal Kubernetes DNS, not the public URL.
- Use: `http://loki-headless.monitoring.svc.cluster.local:3100`
- Instead of: `http://loki.34.x.x.x.nip.io`

### 5. Secure HTTP (TLS/SSL)
The tutorial above uses HTTP for simplicity over `nip.io`.
To make it "Green Lock" secure, you need to install Cert-Manager:

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
```

Then add a ClusterIssuer and update your Ingress annotations in `stack-values.yaml` to include:
```yaml
cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

