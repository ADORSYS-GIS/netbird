# 📘 02 | Observability & Performance Baselines (Ansible Stack)

**SLOs, SLIs, and Dashboards**

[[_TOC_]]

---

## SLOs & SLIs

- **Availability SLO**: 99.99% uptime for the Management API.
- **Latency SLI**: 99th percentile of response time < 300ms.
- **Failover SLI**: Virtual IP switch via Keepalived in < 5 seconds.

## Critical Dashboards

- [📈 **HAProxy Stats**](https://netbird.example.com:8404/stats)
- [🪵 **Management Logs**](journalctl -u netbird-management)
- [📊 **PgBouncer Metrics**](docker logs pgbouncer)

---
*Last Updated: 2026-02-27*
