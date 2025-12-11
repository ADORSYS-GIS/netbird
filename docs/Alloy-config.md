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
  host = "unix:///var/run/docker.sock"  // Connect to Docker daemon socket
}

// Step 2: Collect logs from discovered containers
loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"  // Docker daemon socket path
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
    {__path__ = "/var/log/nginx/*.log", job = "nginx"},           
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
// Note: Deploy node-exporter container to expose system metrics at port 9100
prometheus.scrape "node_metrics" {
  targets = [{
    __address__ = "node-exporter:9100"  // Node exporter endpoint for system metrics
  }]
  job_name = "node"  // Job name for identification in Prometheus
  forward_to = [prometheus.remote_write.prometheus.receiver]  // Send to remote Prometheus
}

// Step 2: Discover Docker containers that expose metrics
discovery.docker "metrics_targets" {
  host = "unix:///var/run/docker.sock"  // Connect to Docker daemon
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

**Before running queries, you must select the correct data source in Grafana:**

1. **For Logs Verification**: 
   - Go to Grafana dashboard
   - Click on the data source selector (top-left corner)
   - Select **Loki** data source
   - Then run the logs query

2. **For Metrics Verification**:
   - Go to Grafana dashboard
   - Click on the data source selector (top-left corner)
   - Select **Prometheus** data source
   - Then run the metrics query

3. **For Traces Verification**:
   - Go to Grafana dashboard  
   - Click on the data source selector (top-left corner)
   - Select **Tempo** data source
   - Then run the traces query

### Logs Verification
```promql
# Check if logs are being received (example)
{job="myapp"} |= "test"

# Check Docker container logs
{job="containers"} |= "error"

# Check system logs
{job="systemd-journal"} |= "error"
```

*Many other LogQL queries available for filtering and searching logs.*
**Reference**: [Grafana LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)

### Metrics Verification
```promql
# Check if system metrics are being received
up{job="node"}

# Check CPU usage
rate(cpu_total[5m]) by (instance)

# Check memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Check application metrics (if available)
rate(http_requests_total[5m]) by (service)

# Check Alloy's own metrics
alloy_build_info
```

*Many other PromQL queries available for system and application monitoring.*
**Reference**: [Prometheus PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

### Traces Verification
```promql
# Check trace metrics (example)
sum(rate(traces_received_total[5m])) by (service)

# Check span metrics
rate(traces_spanmetrics_latency_bucket[5m])

# Check trace errors
rate(traces_spanmetrics_latency_count{status="error"}[5m])
```

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
