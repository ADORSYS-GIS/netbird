# Monitoring & Alerting

Comprehensive guide for monitoring NetBird infrastructure health and performance using Prometheus and Grafana.

## Overview

<details open>
<summary>Monitoring & Alerting Workflow</summary>

```
┌──────────────────────────────────────────────────────────────┐
│                  MONITORING & ALERTING WORKFLOW              │
└──────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ Metrics Scrape  │
    │ Prometheus Conf │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Visualization   │
    │ Grafana Dash    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Alerting        │
    │ Alertmanager    │
    └─────────────────┘
```

### Metrics Endpoints

| Service | Endpoint | Port | Notes |
|---------|----------|------|-------|
| Management API | `http://<node-ip>:8081/metrics` | 8081 | REST/Dashboard metrics |
| Management HA | `http://<node-ip>:9091/metrics` | 9091 | Cluster sync & inter-node stats |
| Signal | `http://<node-ip>:8083/metrics` | 8083 | Connection stats |
| Relay | `http://<relay-ip>:33080/metrics` | 33080 | Traffic traversal stats |
| HAProxy | `http://<proxy-ip>:8404/stats` | 8404 | Frontend/Backend health |
| PgBouncer | `http://<mgmt-ip>:9127/metrics` | 9127 | Connection pool stats |

</details>

## Procedures

<details open>
<summary>Monitoring Implementation Steps</summary>

### Prometheus Scrape Configuration

<details>
<summary>Execution Details</summary>

Add the following jobs to your `prometheus.yml` to track the HA cluster:

```yaml
scrape_configs:
  - job_name: 'netbird-management'
    static_configs:
      - targets: ['10.0.1.10:8081', '10.0.1.11:8081', '10.0.1.12:8081']
```

</details>

### Grafana Dashboard Import

<details>
<summary>Execution Details</summary>

**1. Management Overview:**
Import Dashboard ID `1860` for Node Exporter and NetBird custom dashboards from `examples/monitoring/grafana-dashboards/`.

**2. HAProxy Monitoring:**
Enable the HAProxy Prometheus exporter and import Dashboard ID `12693`.

</details>

### Critical Alerts (Alertmanager)

<details>
<summary>Verification Details</summary>

| Alert Name | Condition | Severity |
|------------|-----------|----------|
| `NetBirdServiceDown` | `up == 0` | Critical |
| `ClusterSyncFailed` | `netbird_management_cluster_sync_status == 0` | Critical |
| `HAProxyBackendDown` | `haproxy_backend_up == 0` | Critical |
| `PgBouncerPoolFull` | `pgbouncer_pools_client_waiting > 0` | Warning |

</details>

</details>

## Related Documentation

<details>
<summary>Additional Resources</summary>

| Document | Description |
|----------|-------------|
| [Troubleshooting Guide](../runbooks/troubleshooting.md) | Debugging with metrics |
| [Disaster Recovery](./disaster-recovery.md) | Backup procedures |

</details>
