# Monitoring & Alerting

Comprehensive guide for monitoring NetBird infrastructure health and performance.

## Overview

NetBird exposes Prometheus-compatible metrics for observability. This guide covers:
- **Metrics collection** (Prometheus)
- **Visualization** (Grafana)
- **Logging** (Loki/CloudWatch/ELK)
- **Alerting** (Alertmanager)

## Metrics Architecture

### NetBird Metrics Endpoints

| Service | Endpoint | Port | Notes |
|---------|----------|------|-------|
| Management | `http://<private-ip>:8081/metrics` | 8081 | Internal metrics only |
| Signal | `http://<private-ip>:8082/metrics` | 8082 | Connection stats |
| Caddy | `http://localhost:2019/metrics` | 2019 | Requires explicit enablement |

### Key Metrics

```promql
# Active peer connections
netbird_management_peers_connected

# Signal server active connections
netbird_signal_connections_active

# Peer connection errors
netbird_management_peer_connection_errors_total

# API request duration
netbird_management_http_request_duration_seconds

# Go runtime metrics
go_goroutines
go_memstats_alloc_bytes
```

---

## Prometheus Setup

### Option 1: Docker Compose Stack

See [examples/monitoring/docker-compose.yml](../../examples/monitoring/docker-compose.yml) for a complete Prometheus + Grafana + Loki stack.

```bash
cd examples/monitoring
docker-compose up -d
```

Access:
- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3000` (admin/admin)
- **AlertManager**: `http://localhost:9093`

### Option 2: Ansible Deployment

Add monitoring role to your playbook:

```yaml
- name: Deploy Monitoring Stack
  hosts: monitoring
  roles:
    - prometheus
    - grafana
    - alertmanager
```

### Prometheus Configuration

Example `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - 'alerts.yml'

scrape_configs:
  - job_name: 'netbird-management'
    static_configs:
      - targets:
          - '10.0.1.10:8081'
          - '10.0.1.11:8081'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+).*'

  - job_name: 'netbird-signal'
    static_configs:
      - targets:
          - '10.0.1.10:8082'
          - '10.0.1.11:8082'

  - job_name: 'caddy'
    static_configs:
      - targets: ['10.0.1.12:2019']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '10.0.1.10:9100'
          - '10.0.1.11:9100'
          - '10.0.1.12:9100'
```

---

## Alerting Rules

Example alert definitions (`alerts.yml`):

```yaml
groups:
  - name: netbird
    interval: 30s
    rules:
      - alert: NetBirdServiceDown
        expr: up{job=~"netbird-.*"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "NetBird service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} on {{ $labels.instance }} has been down for 2+ minutes"

      - alert: NetBirdHighErrorRate
        expr: rate(netbird_management_peer_connection_errors_total[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High peer connection error rate"
          description: "Error rate: {{ $value }} errors/sec on {{ $labels.instance }}"

      - alert: NetBirdHighMemory
        expr: |
          (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) 
          / node_memory_MemTotal_bytes > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90%"

      - alert: NetBirdHighCPU
        expr: |
          100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for 10+ minutes"

      - alert: NetBirdDatabaseConnectionFailed
        expr: |
          netbird_management_database_connection_errors_total > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection errors"
          description: "NetBird cannot connect to database"

      - alert: NetBirdDiskSpaceLow
        expr: |
          (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Less than 10% disk space remaining"
```

---

## Grafana Dashboards

### Pre-built Dashboards

1. **NetBird Overview** - Active peers, connections, API metrics
2. **Node Exporter Full** - Import dashboard ID: `1860`
3. **Caddy Exporter** - Import dashboard ID: `14280`

### Custom Dashboard Panels

**Active Peers:**
```promql
netbird_management_peers_connected
```

**Connection Success Rate:**
```promql
rate(netbird_management_peer_connections_success_total[5m])
/ 
rate(netbird_management_peer_connections_total[5m])
```

**API Request Latency (p95):**
```promql
histogram_quantile(0.95, 
  rate(netbird_management_http_request_duration_seconds_bucket[5m])
)
```

**Signal Server Load:**
```promql
sum(rate(netbird_signal_messages_total[5m])) by (instance)
```

---

## Logging

### Centralized Logging Options

#### Option 1: Loki Stack (Recommended)

Deploy Loki + Promtail for log aggregation:

```yaml
# docker-compose.yml
version: '3.8'
services:
  loki:
    image: grafana/loki:2.9.0
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - loki-data:/loki

  promtail:
    image: grafana/promtail:2.9.0
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
```

#### Option 2: Cloud-Native Logging

**AWS CloudWatch:**
```bash
# Install CloudWatch agent on each host
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

**GCP Cloud Logging:**
```bash
# Google Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
```

### Log Aggregation Queries

**Recent Errors (Loki):**
```logql
{job="netbird-management"} |~ "error|ERROR|exception"
```

**Failed Authentication Attempts:**
```logql
{job="netbird-management"} |~ "authentication failed"
```

---

## Health Checks

### Service Health Endpoints

```bash
# Management server health
curl -f http://10.0.1.10:8081/health
# Expected: {"status":"ok"}

# Signal server health
curl -f http://10.0.1.10:8082/health

# Caddy health
curl -f http://10.0.1.12:2019/health
```

### Automated Health Monitoring

**Uptime Kuma** (self-hosted):
```bash
docker run -d \
  --name uptime-kuma \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

**External Monitoring**:
- **UptimeRobot**: Free external monitoring
- **Pingdom**: Commercial option
- **StatusCake**: Free tier available

---

## Cloud-Native Monitoring

### AWS CloudWatch

```hcl
# Terraform: Enable detailed monitoring
resource "aws_instance" "netbird" {
  monitoring = true
  # ... other config
}

resource "aws_cloudwatch_metric_alarm" "netbird_cpu" {
  alarm_name          = "netbird-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "NetBird instance high CPU"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### GCP Cloud Monitoring

```bash
# Create uptime check
gcloud monitoring uptime-checks create https-check \
  --display-name="NetBird Dashboard" \
  --monitored-resource-type="uptime-url" \
  --host="vpn.example.com" \
  --path="/health"
```

---

## Example Monitoring Stack Deployment

See [examples/monitoring/](../../examples/monitoring/) for complete setup including:
- `docker-compose.yml` - Full monitoring stack
- `prometheus.yml` - Prometheus configuration
- `alerts.yml` - Alert rules
- `grafana-dashboards/` - Pre-built dashboards

**Quick Start:**
```bash
cd examples/monitoring
docker-compose up -d

# Access Grafana
open http://localhost:3000
```

---

## Related Documentation

- [Troubleshooting Guide](./troubleshooting.md) - Debug issues using metrics/logs
- [Disaster Recovery](./disaster-recovery.md) - Backup monitoring data
- [Security Hardening](./security-hardening.md) - Secure monitoring endpoints
