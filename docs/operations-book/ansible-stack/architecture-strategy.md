# NetBird Ansible Stack Operations Guide
**Service Owner**: Platform Team | **SLA**: 99.99% | **Env**: Production

## Architecture & High Availability Strategy

<details open>
<summary>Click to expand System Design & Traffic Flow</summary>

```text
┌──────────────────────────────────────────────────────────────┐
│                  NETBIRD HA TRAFFIC FLOW                     │
└──────────────────────────────────────────────────────────────┘
      [Internet Users]
             │
             ▼
    [DNS Round Robin / Load Balancer]
             │
    ┌────────┴────────┐
    ▼                 ▼
[HAProxy Node 1]           [HAProxy Node 2]
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
| **HAProxy** | Multiple Nodes (DNS/LB) | Degraded (Reduced Capacity) | Per-Node |
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
| **HAProxy Health** | `HAProxy Stats` | All backends UP | Any backend DOWN (1m) |

### Critical Links
- [HAProxy Stats Dashboard](https://netbird.example.com:8404/stats)
- [Management Logs](journalctl -u netbird-management)
- [PgBouncer Metrics](docker logs pgbouncer)

</details>

---

## 03. Maintenance Lifecycle
<details>
<summary>Standard Operating Procedures (SOPs)</summary>

| Task | Frequency | Automated? | Runbook Link |
| :--- | :--- | :--- | :--- |
| **Deployment** | As needed | ✅ Yes (TF/Ansible) | [Deployment](../../runbooks/ansible-stack/deployment.md) |
| **Rolling Upgrade**| Version release | ✅ Yes (Ansible) | [Upgrade](../../runbooks/ansible-stack/upgrade.md) |
| **Cert Renewal** | Every 60 days | ✅ Yes (ACME.sh) | N/A (Automated) |
| **Security Validation** | Weekly | ✅ Yes (Ansible) | N/A (Automated) |

</details>
