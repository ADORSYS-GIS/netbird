# 08 - Monitoring & Alerting

This document describes how to monitor the NetBird infrastructure.

## Metrics Architecture

NetBird services expose Prometheus-compatible metrics.

### Endpoints
*   **Management Service**: `http://<Private-IP>:8081/metrics` (or configured port)
*   **Signal Service**: `http://<Private-IP>:8082/metrics`
*   **Caddy**: `http://localhost:2019/metrics` (Needs enablement in Caddyfile)

## Setting up Prometheus

To scrape these metrics, deploy a Prometheus instance inside the VPC (or accessible via VPN).

**Scrape Config Example:**

```yaml
scrape_configs:
  - job_name: 'netbird-management'
    static_configs:
      - targets: ['10.0.1.5:8081'] # Management Private IP
  - job_name: 'caddy'
    static_configs:
      - targets: ['10.0.1.4:2019'] # Reverse Proxy Private IP
```

## Grafana Dashboard

Recommended panels for NetBird:
1.  **Connected Peers**: `netbird_management_peers_connected`
2.  **Signal Connections**: `netbird_signal_connections_active`
3.  **Go Runtime**: `go_goroutines`, `go_memstats_alloc_bytes`

## Alerting Rules (Recommended)

1.  **High Memory Usage**: `node_memory_MemAvailable_bytes < 10%`
2.  **High CPU Usage**: `rate(node_cpu_seconds_total{mode="idle"}[5m]) < 0.1`
3.  **Service Down**: `up{job="netbird-management"} == 0`
4.  **Failed Peer Connections**: Rate of `netbird_management_peer_connection_errors` > Threshold.

## Logs
*   **Docker Logs**: `docker logs -f netbird-management`
*   **System Logs**: `/var/log/syslog`
*   **Aggregation**: Recommend setup of **Loki** + **Promtail** on each node to ship logs to a central server.

## Next Steps
Proceed to [09-architecture-decisions.md](./09-architecture-decisions.md).
