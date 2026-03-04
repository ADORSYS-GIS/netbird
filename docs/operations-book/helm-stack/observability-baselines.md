# Observability & Performance Baselines (Helm Stack)

**SLOs, SLIs, and Dashboards**

## Service Level Objectives & Indicators

<details open>
<summary>Performance Targets and Metrics</summary>

### Service Level Objectives (SLOs)
- **Availability SLO**: 99.9% uptime for the Management API and Dashboard
- **Latency SLI**: 95th percentile of API responses < 200ms
- **Error Rate SLI**: Less than 1% of gRPC/HTTP requests return 5xx errors

</details>

## Monitoring Stack

<details open>
<summary>Monitoring Infrastructure</summary>

### Cloud Monitoring
- **GCP Monitoring**: Cloud SQL metrics, GKE Node/Cluster health
- **Prometheus/Grafana**: NetBird internal metrics (via `enable_metrics = true`)
- **Alerting**: Critical alerts for Database CPU > 80% and Ingress 5xx spikes

### Key Metrics
| Metric | Source | Threshold | Alert |
|--------|--------|-----------|-------|
| Database CPU | Cloud SQL | < 80% | Critical if > 80% for 5m |
| API Latency | Prometheus | P95 < 200ms | Warning if > 300ms |
| Error Rate | Ingress | < 1% | Critical if > 5% |
| Pod Restarts | Kubernetes | < 3/hour | Warning if > 5/hour |

</details>

## Related Documentation

- [Architecture Strategy](./architecture-strategy.md)
- [Maintenance Lifecycle](./maintenance-lifecycle.md)
- [Monitoring & Alerting](../monitoring-alerting.md)

