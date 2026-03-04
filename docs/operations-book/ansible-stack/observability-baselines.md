# Observability & Performance Baselines (Ansible Stack)

**SLOs, SLIs, and Dashboards**

## Service Level Objectives & Indicators

<details open>
<summary>Performance Targets and Metrics</summary>

### Service Level Objectives (SLOs)
- **Availability SLO**: 99.99% uptime for the Management API
- **Latency SLI**: 99th percentile of response time < 300ms
- **Load Balancing**: Multiple HAProxy nodes with DNS round-robin or external load balancer

</details>

## Monitoring and Logging Resources

<details open>
<summary>Critical Dashboards and Logs</summary>

| Resource | Access | Purpose |
|----------|--------|---------|
| **HAProxy Stats** | [https://netbird.example.com:8404/stats](https://netbird.example.com:8404/stats) | Load balancer health and traffic |
| **Management Logs** | `journalctl -u netbird-management` | Service logs and errors |
| **PgBouncer Metrics** | `docker logs pgbouncer` | Connection pool statistics |

</details>

## Related Documentation

- [Architecture Strategy](./architecture-strategy.md)
- [Maintenance Lifecycle](./maintenance-lifecycle.md)
- [Monitoring & Alerting](../monitoring-alerting.md)

