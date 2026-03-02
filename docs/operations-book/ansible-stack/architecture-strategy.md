# 📘 NetBird Ansible Stack | Operations Book
**Service Owner**: Platform Team | **SLA**: 99.99% | **Env**: Production

[[_TOC_]]

---

## 01. Architecture & High Availability Strategy
<details open>
<summary>System Design & Traffic Flow</summary>

```text
┌──────────────────────────────────────────────────────────────┐
│                  NETBIRD HA TRAFFIC FLOW                      │
└──────────────────────────────────────────────────────────────┘
      [Internet Users]
             │
             ▼
    [Virtual IP (Keepalived)]
             │
    ┌────────┴────────┐
    ▼                 ▼
[HAProxy Node 1] <─── Heartbeat ───> [HAProxy Node 2]
(Active)                             (Passive)
    │                 │
    └────────┬────────┘
             │
             ▼
    [Management Cluster] (3-node HA)
    [Relay/Signal Servers]
             │
             ▼
    [PgBouncer Pooler]
             │
             ▼
    [PostgreSQL Database]
```

### Component Registry & Redundancy
| Component | HA Strategy | Failure Impact | Blast Radius |
| :--- | :--- | :--- | :--- |
| **Keepalived** | VRRP Virtual IP Failover | Critical (IP Loss) | Global |
| **HAProxy** | Active/Passive Failover | Critical (Entry Loss) | Global |
| **Management**| 3-node Unified Cluster | Degraded (Quorum) | Service-wide |
| **PgBouncer** | Local Pooler per Mgmt Node | Performance | Local Node |
| **Database**  | Multi-AZ / External | Critical (Data Loss)| Global |

</details>

---

## 02. Observability & Performance Baselines
<details>
<summary>SLOs, SLIs, and Dashboards</summary>

### Service Level Indicators (SLIs)
| Metric | Source | Healthy Threshold | Alert Trigger |
| :--- | :--- | :--- | :--- |
| **Management Latency** | `curl /health` | P99 < 300ms | > 1s (2m) |
| **Agent Quorum** | `cluster_control -l` | 3 Nodes Online | < 2 Nodes (1m) |
| **VIP Failover** | `Keepalived Logs` | < 5s switch | > 10s downtime |

### Critical Links
- [📈 **HAProxy Stats Dashboard**](https://netbird.example.com:8404/stats)
- [🪵 **Management Logs**](journalctl -u netbird-management)
- [📊 **PgBouncer Metrics**](docker logs pgbouncer)

</details>

---

## 03. Maintenance Lifecycle
<details>
<summary>Standard Operating Procedures (SOPs)</summary>

| Task | Frequency | Automated? | Runbook Link |
| :--- | :--- | :--- | :--- |
| **Deployment** | As needed | ✅ Yes (TF/Ansible) | [Deployment](../runbooks/netbird-ansible-deployment.md) |
| **Rolling Upgrade**| Version release | ✅ Yes (Ansible) | [Upgrade](../runbooks/netbird-ansible-upgrade.md) |
| **Cert Renewal** | Every 60 days | ✅ Yes (ACME.sh) | N/A (Automated) |
| **Security Validation** | Weekly | ✅ Yes (Ansible) | N/A (Automated) |

</details>
