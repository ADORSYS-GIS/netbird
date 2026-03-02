# 📘 02 | Observability & Performance Baselines

**SLOs, SLIs, and Dashboards**

[[_TOC_]]

---

## SLOs & SLIs

- **Availability SLO**: 99.9% uptime for the Management API and Dashboard.
- **Latency SLI**: 95th percentile of API responses should be < 200ms.
- **Error Rate SLI**: Less than 1% of gRPC/HTTP requests should return 5xx errors.

## Monitoring Stack

- **GCP Monitoring**: Cloud SQL metrics, GKE Node/Cluster health.
- **Prometheus/Grafana**: NetBird internal metrics (via `enable_metrics = true`).
- **Alerting**: Critical alerts for Database CPU > 80% and Ingress 5xx spikes.

---
*Last Updated: 2026-02-27*
