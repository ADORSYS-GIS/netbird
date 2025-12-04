# NetBird Monitoring and Observability on Kubernetes

This document describes how to deploy the `monitor-netbird` observability stack on a Kubernetes cluster using Helm.

The goal is to provide a production-style setup where you can:

- Run a self-hosted NetBird control plane in Kubernetes.
- Collect **logs** from the cluster and all NetBird-related components.
- Collect **metrics** from the cluster and components.
- Explore everything in **Grafana** using **Prometheus**, **Loki**, and **Mimir** as data sources.

The instructions below assume you are in the root of this repository.

---

## Prerequisites

- A Kubernetes cluster (e.g., K3s, Minikube, EKS, GKE, AKS)
- `kubectl` configured to connect to your cluster.
- `helm` installed (version 3.x or higher).
- Basic understanding of Kubernetes concepts (Pods, Services, Deployments, Namespaces).
- NetBird deployed in your Kubernetes cluster (or accessible from it).

---

## 1. Deploying the monitoring stack with Helm

This section describes how to deploy the monitoring stack using Helm charts within your Kubernetes cluster.

1.  **Create the `monitoring` namespace:**
    ```bash
    kubectl apply -f monitor-netbird/kubernetes/namespace.yaml
    ```

2.  **Add Helm repositories:**
    ```bash
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    ```

3.  **Install the monitoring stack:**
    Navigate to the Helm chart directory and install the stack.
    ```bash
    cd monitor-netbird/kubernetes/helm/monitoring-stack
    helm dependency update
    helm install monitoring-stack . -n monitoring -f ../configs/grafana-values.yaml -f ../configs/loki-values.yaml -f ../configs/mimir-values.yaml -f ../configs/prometheus-values.yaml
    cd ../../../
    ```
    This command installs Grafana, Loki, Mimir, and Prometheus into the `monitoring` namespace, using the custom `values.yaml` files for configuration.

4.  **Verify the deployment:**
    Check the status of the deployed pods in the `monitoring` namespace:
    ```bash
    kubectl get pods -n monitoring
    ```
    All pods should eventually reach a `Running` or `Completed` state.

---

## 2. Accessing Grafana

By default, Grafana is exposed via a NodePort service. To access Grafana, you need the IP address of one of your Kubernetes nodes and the NodePort.

1.  **Get Grafana NodePort:**
    ```bash
    kubectl get svc monitoring-stack-grafana -n monitoring
    ```
    Look for the `NodePort` in the output (e.g., `30300:3000/TCP`).

2.  **Access Grafana in your browser:**
    Open your browser and go to:
    ```text
    http://<YOUR_NODE_IP>:<GRAFANA_NODEPORT>/
    ```
    Replace `<YOUR_NODE_IP>` with the IP address of one of your Kubernetes nodes and `<GRAFANA_NODEPORT>` with the NodePort obtained in the previous step (e.g., `30300`).

3.  **Login:**
    Grafana runs with default admin credentials (`admin`/`admin`) unless overridden in `grafana-values.yaml`. Change the admin password after first login in any environment accessible to others.

4.  **Data Sources:**
    The Helm chart automatically configures Prometheus, Loki, and Mimir as data sources within Grafana using their internal Kubernetes service names. You should not need to manually configure them.
    -   **Prometheus:** `http://monitoring-stack-prometheus-server:80`
    -   **Loki:** `http://monitoring-stack-loki-gateway:80`
    -   **Mimir:** `http://monitoring-stack-mimir-distributed-nginx:80/prometheus`

    You can verify the data sources by navigating to **Connections** → **Data sources** in Grafana.

---

## 3. What gets scraped and collected

With this setup, the core monitoring stack will collect:

-   **Host metrics**
    -   From `node-exporter` (deployed as a DaemonSet within the monitoring stack).
    -   Scraped by Prometheus at `http://monitoring-stack-prometheus-node-exporter:9100`.
    -   All series are labeled `job="node-exporter"` and `instance="node-exporter"`.

-   **Service metrics**
    -   Loki, Grafana, Mimir, and Prometheus components expose their own `/metrics` endpoints.
    -   These internal metrics are scraped by Prometheus under their respective jobs (e.g., `loki`, `grafana`, `mimir-distributor`, `prometheus`).

This ensures that the monitoring stack is self-observing and provides insights into its own health and performance.

---

## 4. Example queries and dashboards

For initial exploration and to verify data collection, you can use Grafana's Explore feature.

-   **Prometheus Metrics:**
    -   To view host CPU usage: `node_cpu_seconds_total`
    -   To view Prometheus's own health metrics: `prometheus_up`
    -   To view Loki's ingester metrics: `loki_ingester_chunks_stored_total`

-   **Loki Logs:**
    -   To view logs from Loki's components: `{job="loki"}`
    -   To view logs from Grafana: `{job="grafana"}`

Refer to the `docs/Monitoring-NetBird-Observability-Docker-Compose.md` for more detailed example queries and dashboard configurations, as the query language (PromQL for Prometheus, LogQL for Loki) remains consistent across deployment methods.

---

## 5. Production considerations

This repository is geared towards **test and lab deployments**, but the components and patterns are production-grade. For production use, you should additionally consider:

-   Using real DNS names instead of raw IPs.
-   Enabling TLS (for NetBird, Grafana, Prometheus, Loki) and disabling the insecure-origin browser flags.
-   Changing default credentials and integrating with your identity provider.
-   Enabling retention policies and backups for Prometheus and Loki.
-   Restricting access to the Docker socket that Alloy uses for log collection.
-   Implementing proper resource limits and requests for all Kubernetes deployments.
-   Configuring highly available deployments for critical components.

---

## 6. Next steps

From here, once the core monitoring stack is verified, you can:

-   Integrate external agents (like Grafana Alloy or NetBird events exporter) to collect logs and metrics from other applications, VMs, or hosts.
-   Build custom Grafana dashboards for cluster health, application performance, and specific use cases.
-   Add alerting rules in Prometheus and route them via Alertmanager.

The `monitor-netbird` stack is intended to be a clean, understandable baseline you can confidently adapt to your own infrastructure.