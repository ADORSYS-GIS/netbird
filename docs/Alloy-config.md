# Grafana Alloy: Docker Compose Deployment Guide

## Overview
Grafana Alloy is a unified telemetry collector that gathers logs, metrics, and traces from applications and forwards them to an LGTM stack.

**Why use Alloy?** While Prometheus uses a pull model and scrapes metrics itself, Alloy acts as a central collector that can:
- Scrape logs from applications and push to Loki
- Collect traces from various protocols and send to Tempo
- Provide a single deployment point for log and trace collection

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

volumes:
  alloy-data:
```

### 2. Alloy Configuration

The Alloy configuration defines how to collect logs and traces from different sources and send them to your LGTM stack endpoints.

**config.alloy:**
```alloy
logging {
  level  = "info"
  format = "logfmt"
}

// Loki - Log Collection and Forwarding
loki.write "loki" {
  endpoint {
    url = "https://loki.<YOUR_DOMAIN>/loki/api/v1/push"
  }
}

// Example 1: Collect Docker container logs
loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.containers.targets
  forward_to = [loki.process.containers.receiver]
}

loki.process "containers" {
  stage.docker {}
  stage.labels {
    values = {
      container_name = "container_name",
      host           = "host",
    }
  }
  forward_to = [loki.write.loki.receiver]
}

discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

// Example 2: Collect application logs from files
loki.source.file "app_logs" {
  targets = [
    {__path__ = "/var/log/myapp/*.log", job = "myapp"},
  ]
  forward_to = [loki.write.loki.receiver]
}

// Tempo - Trace Collection
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo.<YOUR_DOMAIN>:4317"
    tls {
      insecure = false
    }
  }
}

// Jaeger receiver (for legacy applications)
otelcol.receiver.jaeger "default" {
  protocols {
    thrift_http {
      endpoint = "0.0.0.0:14268"
    }
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
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

2. **For Traces Verification**:
   - Go to Grafana dashboard  
   - Click on the data source selector (top-left corner)
   - Select **Tempo** data source
   - Then run the traces query

### Logs Verification
```promql
# Check if logs are being received (example)
{job="myapp"} |= "test"
```

*Many other LogQL queries available for filtering and searching logs.*
**Reference**: [Grafana LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)

### Traces Verification
```promql
# Check trace metrics (example)
sum(rate(traces_received_total[5m])) by (service)
```

*Many other PromQL queries available for trace analysis and metrics.*
**Reference**: [Prometheus PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

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

