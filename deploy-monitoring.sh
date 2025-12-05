#!/bin/bash

# deploy_monitoring.sh
# Automates the deployment of the Grafana Stack (Loki, Mimir, Tempo, Prometheus, Grafana)
# Supports Local Ubuntu (k3s) and GKE.

set -e

# Default values
TARGET="local"
NAMESPACE="monitoring-stack"
VALUES_DIR="./generated-values"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --target) TARGET="$2"; shift ;;
        --namespace) NAMESPACE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "Deploying to Target: $TARGET"
echo "Namespace: $NAMESPACE"

# --- Functions ---

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed."
        return 1
    fi
}

setup_local() {
    echo "--- Setting up Local Ubuntu Environment (k3s) ---"
    
    # Check/Install k3s
    if ! command -v k3s &> /dev/null; then
        echo "Installing k3s..."
        curl -sfL https://get.k3s.io | sh -
        echo "k3s installed."
    fi

    echo "Waiting for k3s..."
    # k3s usually starts automatically. We can check kubectl.
    
    # Configure kubectl access
    if [ ! -f ~/.kube/config ]; then
        echo "Copying k3s config to ~/.kube/config..."
        mkdir -p ~/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
        sudo chown $USER ~/.kube/config
        chmod 600 ~/.kube/config
    fi

    KUBECTL="kubectl"
    
    # Install Helm if not present
    if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
}

setup_gke() {
    echo "--- Checking GKE Environment ---"
    check_command kubectl || exit 1
    check_command helm || exit 1
    
    KUBECTL="kubectl"
    
    # Check connection
    if ! $KUBECTL cluster-info &> /dev/null; then
        echo "Error: Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
}

generate_values_files() {
    echo "--- Generating Values Files in $VALUES_DIR ---"
    mkdir -p "$VALUES_DIR"

    cat <<EOF > "$VALUES_DIR/prometheus-values.yml"
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
EOF

    cat <<EOF > "$VALUES_DIR/loki-values.yml"
# loki-values.yaml

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
EOF

    cat <<EOF > "$VALUES_DIR/tempo-values.yml"
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
EOF

    cat <<EOF > "$VALUES_DIR/mimir-values.yml"
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
EOF
}

deploy_stack() {
    echo "--- Deploying Monitoring Stack ---"

    # Add Repos
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # Create Namespace
    if ! $KUBECTL get ns "$NAMESPACE" &> /dev/null; then
        echo "Creating namespace $NAMESPACE..."
        $KUBECTL create ns "$NAMESPACE"
    fi

    # Basic Auth Secret
    if ! $KUBECTL get secret basic-auth -n "$NAMESPACE" &> /dev/null; then
        echo "Creating Basic Auth Secret (admin/password123)..."
        HTPASSWD_FILE=$(mktemp)
        if command -v htpasswd &> /dev/null; then
             htpasswd -bc "$HTPASSWD_FILE" admin password123
        else
             # Fallback: admin:password123 (MD5) - Just for demo, insecure
             # Note: This hash might not work on all systems, but it's a placeholder.
             # Ideally, we should error out or use python.
             # Trying python if available
             if command -v python3 &> /dev/null; then
                 python3 -c 'import crypt; print("admin:" + crypt.crypt("password123", crypt.mksalt(crypt.METHOD_MD5)))' > "$HTPASSWD_FILE"
             else
                 echo "WARNING: 'htpasswd' and 'python3' not found. Cannot generate secure hash."
                 echo "Please install apache2-utils or python3."
                 rm "$HTPASSWD_FILE"
                 exit 1
             fi
        fi
        
        $KUBECTL create secret generic basic-auth \
          --namespace "$NAMESPACE" \
          --from-file=auth="$HTPASSWD_FILE"
        rm "$HTPASSWD_FILE"
    fi

    # Deploy Ingress Controller
    if ! $KUBECTL get ingressclass nginx &> /dev/null; then
        echo "Deploying Nginx Ingress Controller..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx --create-namespace \
          --set controller.service.type=LoadBalancer
    else
        echo "Ingress Class 'nginx' already exists. Skipping Ingress Controller installation."
    fi

    # Deploy Components
    echo "Deploying Kube Prometheus Stack..."
    helm upgrade --install kube-stack prometheus-community/kube-prometheus-stack \
      --namespace "$NAMESPACE" \
      -f "$VALUES_DIR/prometheus-values.yml"

    echo "Deploying Loki..."
    helm upgrade --install loki grafana/loki \
      --namespace "$NAMESPACE" \
      -f "$VALUES_DIR/loki-values.yml"

    echo "Deploying Tempo..."
    helm upgrade --install tempo grafana/tempo \
      --namespace "$NAMESPACE" \
      -f "$VALUES_DIR/tempo-values.yml"

    echo "Deploying Mimir..."
    helm upgrade --install mimir grafana/mimir-distributed \
      --namespace "$NAMESPACE" \
      -f "$VALUES_DIR/mimir-values.yml"

    echo "--- Deployment Complete ---"
    echo "Namespace: $NAMESPACE"
    echo "Check pods: $KUBECTL get pods -n $NAMESPACE"
}

# --- Main Execution ---

if [ "$TARGET" == "local" ]; then
    setup_local
elif [ "$TARGET" == "gke" ]; then
    setup_gke
else
    echo "Invalid target: $TARGET. Use 'local' or 'gke'."
    exit 1
fi

generate_values_files
deploy_stack

