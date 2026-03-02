# 📘 01 | Architecture & High Availability Strategy

**System Design & Traffic Flow**

[[_TOC_]]

---

## Multi-AZ Production Flow

```text
┌──────────────────────────────────────────────────────────────┐
│                  GKE PRODUCTION TRAFFIC FLOW                  │
└──────────────────────────────────────────────────────────────┘
      [GCP Load Balancer] ───► [Ingress-Nginx] ───► [NetBird App Cluster]
                                                      │
                ┌───────────────────────────┴──────────────────────────┐
                ▼                                                      ▼
        [Management/Signal] <───── OIDC Auth ─────> [Keycloak Identity]
                │                                              │
                ▼                                              ▼
        [Cloud SQL (AZ-A)] <───── Sync Replication ─────> [Cloud SQL (AZ-B)]
```

### Component Registry & Redundancy

| Component | HA Strategy | Failure Impact | Blast Radius |
|-----------|-------------|----------------|--------------|
| **Management Server** | Kubernetes Deployment (ReplicaSet) | Connection Management / ACL Updates Unavailable | Regional |
| **Signal Server** | Kubernetes Deployment (ReplicaSet) | New Peer-to-Peer Connections Blocked | Regional |
| **Relay Server (TURN)** | Kubernetes Deployment (ReplicaSet) | NAT Traversal Failure for Relay Peers | Regional |
| **Keycloak (Auth)** | OIDC Integration (External/GKE) | User Authentication & API Access Failure | Global/Regional |
| **PostgreSQL (DB)** | Google Cloud SQL (REGIONAL) | Service Interruption & Potential Data Lock | Regional |
| **Ingress Controller** | Ingress-Nginx LoadBalancer | All External Traffic Blocked | Regional |

---
*Last Updated: 2026-02-27*
