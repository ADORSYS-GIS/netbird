# Grafana Alloy: Docker Compose Deployment Guide

## Overview
Grafana Alloy is a unified telemetry collector that gathers logs, metrics, and traces from applications and forwards them to an LGTM stack.

**Why use Alloy?** While Prometheus uses a pull model and scrapes metrics itself, Alloy acts as a central collector that can:
- Scrape logs from applications and push to Loki
- Collect metrics from applications and systems and forward to Prometheus
- Collect traces from various protocols and send to Tempo
- Provide a single deployment point for log, metric, and trace collection

## Quick Start

### 1. Docker Compose Setup

This deployment runs Alloy as a container that collects telemetry from your applications and forwards it to your external LGTM stack.

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
      - --storage.path=/var/lib/alloy/data
    ports:
      - "12345:12345"  # Alloy UI/metrics
      - "4317:4317"    # OTLP gRPC (traces)
      - "4318:4318"    # OTLP HTTP (traces)
      - "14268:14268"  # Jaeger HTTP (traces)
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
      - alloy-data:/var/lib/alloy/data
    restart: unless-stopped
    environment:
      - LOKI_ENDPOINT=https://loki.<YOUR_DOMAIN>/loki/api/v1/push
      - TEMPO_ENDPOINT=https://tempo.<YOUR_DOMAIN>:4317
      - PROMETHEUS_ENDPOINT=https://prometheus.<YOUR_DOMAIN>/api/v1/write

  # Node Exporter for system metrics collection
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"  # Node exporter metrics endpoint
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    restart: unless-stopped

volumes:
  alloy-data:
```

### 2. Alloy Configuration

The Alloy configuration defines how to collect logs, metrics, and traces from different sources and send them to your LGTM stack endpoints.

**config.alloy:**
```alloy
// =============================================================================
// GRAFANA ALLOY CONFIGURATION
// Collect logs, metrics, and traces from various sources
// =============================================================================

logging {
  level  = "info"
  format = "logfmt"
}

// =============================================================================
// LOKI - LOG COLLECTION AND FORWARDING
// =============================================================================

loki.write "loki" {
  endpoint {
    url = "https://loki.<YOUR_DOMAIN>/loki/api/v1/push"
  }
}

// =============================================================================
// DOCKER CONTAINER LOGS
// =============================================================================
// Step 1: Discover all running Docker containers
discovery.docker "containers" {
  host = "unix://var/run/docker.sock"  // Connect to Docker daemon socket
}

// Step 2: Collect logs from discovered containers
loki.source.docker "containers" {
  host       = "unix://var/run/docker.sock"  // Docker daemon socket path
  targets    = discovery.docker.containers.targets  // Use discovered containers as targets
  forward_to = [loki.process.containers.receiver]  // Send logs to processing stage
}

// Step 3: Process and enrich logs with labels
loki.process "containers" {
  stage.docker {}  // Parse Docker-specific log format and metadata
  
  // Add custom labels for better filtering and searching
  stage.labels {
    values = {
      container_name = "container_name",  // Extract container name
      host           = "host",            // Add host information
    }
  }
  forward_to = [loki.write.loki.receiver]  // Send processed logs to Loki
}

// =============================================================================
// SYSTEM LOGS (journald) - Collect systemd/system logs
// =============================================================================
// Step 1: Collect logs from systemd journal
loki.source.journal "system_logs" {
  forward_to = [loki.write.loki.receiver]  // Send directly to Loki (no processing needed)
  labels = {
    job = "systemd-journal",  // Label for easy identification in Grafana
  }
}

// =============================================================================
// FILE LOGS - Collect application logs from files
// =============================================================================
// Step 1: Define which log files to collect and assign job names
loki.source.file "app_logs" {
  targets = [
    // Custom application logs
    {__path__ = "/var/log/myapp/*.log", job = "myapp"},                      
    {__path__ = "/var/log/mysql/*.log", job = "mysql"},          
    {__path__ = "/var/log/redis/*.log", job = "redis"},           
    {__path__ = "/var/log/auth.log", job = "auth"},           
    {__path__ = "/var/log/syslog", job = "system"},             
  ]
  forward_to = [loki.write.loki.receiver]  // Send logs directly to Loki
}

// =============================================================================
// PROMETHEUS METRICS COLLECTION - System and Application Metrics
// =============================================================================

// Step 1: Collect system metrics (CPU, memory, disk, network)
prometheus.scrape "node_metrics" {
  targets = [{
    __address__ = "node-exporter:9100"  // Node exporter endpoint for system metrics
  }]
  job_name = "node"  // Job name for identification in Prometheus
  forward_to = [prometheus.remote_write.prometheus.receiver]  // Send to remote Prometheus
}

// Step 2: Discover Docker containers that expose metrics
discovery.docker "metrics_targets" {
  host = "unix://var/run/docker.sock"  // Connect to Docker daemon
}

// Step 3: Filter containers to only include those with Prometheus metrics enabled
discovery.relabel "metrics_relabel" {
  targets = discovery.docker.metrics_targets.targets
  
  // Keep only containers labeled with prometheus_scrape=true
  rule {
    source_labels = ["__meta_docker_container_label_prometheus_scrape"]
    regex         = "true"
    action        = "keep"
  }
}

// Step 4: Scrape metrics from discovered application containers
prometheus.scrape "app_metrics" {
  targets         = discovery.relabel.metrics_relabel.output  // Use filtered containers
  scrape_interval = "15s"  // How often to collect metrics
  forward_to      = [prometheus.remote_write.prometheus.receiver]  // Send to remote Prometheus
}

// Step 5: Send all collected metrics to remote Prometheus
prometheus.remote_write "prometheus" {
  endpoint {
    url = "https://prometheus.<YOUR_DOMAIN>/api/v1/write"  // Remote Prometheus endpoint
  }
}

// =============================================================================
// TEMPO - TRACE COLLECTION
// =============================================================================

// Step 1: OTLP receiver for modern applications (OpenTelemetry)
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"  // gRPC endpoint for trace data
  }
  http {
    endpoint = "0.0.0.0:4318"  // HTTP endpoint for trace data
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]  // Forward traces to Tempo exporter
  }
}

// Step 2: Export collected traces to Tempo
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo.<YOUR_DOMAIN>:4317"  // Tempo server endpoint
    tls {
      insecure = false  // Use secure TLS connection
    }
  }
}

// Step 3: Jaeger receiver for legacy applications
otelcol.receiver.jaeger "default" {
  protocols {
    thrift_http {
      endpoint = "0.0.0.0:14268"  // HTTP endpoint for Jaeger thrift protocol
    }
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]  // Forward traces to Tempo exporter
  }
}
```

### 3. Deployment

```bash

# Start Alloy
docker-compose up -d

# Verify connectivity
docker-compose logs alloy

# Test configuration
docker exec alloy alloy tools check /etc/alloy/config.alloy
```

## Verification Queries

Use these queries in Grafana to verify data is flowing correctly.

**Before running queries, select the appropriate data source in Grafana:**
- Loki for logs, Prometheus for metrics, Tempo for traces

| Data Type | Data Source | Example Queries | Purpose |
|-----------|-------------|----------------|---------|
| **Logs** | Loki | `{job="myapp"} |= "test"`<br>`{job="containers"} |= "error"`<br>`{job="systemd-journal"} |= "error"` | Verify log collection from applications, containers, and system |
| **Metrics** | Prometheus | `up{job="node"}`<br>`rate(cpu_total[5m])`<br>`alloy_build_info` | Check system metrics, CPU usage, and Alloy health |
| **Traces** | Tempo | `sum(rate(traces_received_total[5m]))`<br>`rate(traces_spanmetrics_latency_bucket[5m])` | Verify trace ingestion and span metrics |

**References:**
- [Grafana LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Prometheus PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Troubleshooting

### Check Alloy Status
```bash
# View logs
docker-compose logs -f alloy

# Check configuration
docker exec alloy alloy tools check /etc/alloy/config.alloy

# View metrics
curl http://localhost:12345/metrics
```

### Common Issues

**No logs in Loki:**
```bash
# Check if Alloy is receiving logs
curl http://localhost:12345/metrics | grep loki

# Verify Loki endpoint
curl https://loki.<YOUR_DOMAIN>/ready
```

**No traces in Tempo:**
```bash
# Check trace ingestion
curl http://localhost:12345/metrics | grep traces

# Test Tempo endpoint
curl https://tempo.<YOUR_DOMAIN>:3200/ready
```

## Production Considerations

1. **Resource Limits**: Set CPU/memory limits in production Docker Compose
2. **Security**: Use TLS certificates for external endpoints
3. **High Availability**: Run multiple Alloy instances for critical environments
4. **Log Retention**: Configure appropriate retention policies in your LGTM stack
5. **Trace Sampling**: Use sampling for high-volume applications to reduce storage costs

## Integration Flow

This Alloy setup provides a complete telemetry pipeline:

- **Logs**: Application/Docker logs → Alloy → Loki
- **Traces**: Application traces (OTLP/Jaeger) → Alloy → Tempo  
- **Visualization**: All data available in Grafana

---

**Want to learn more about Alloy?** Check out the [official Grafana Alloy documentation](https://grafana.com/docs/alloy/latest/) for advanced configuration options, integrations, and best practices for production deployments.
