# NetBird Infrastructure Guide

This document provides a high-level overview of the production-grade NetBird infrastructure deployed on Google Kubernetes Engine (GKE).

## 1. Architecture Overview

The deployment follows a hub-and-spoke architecture where the **Management Server** acts as the central authority, and **Peers** connect to each other directly (P2P) or via **Relay Servers**.

### Component Diagram (Logical)
```text
[ Users / Peers ] <---(GRPC/UDP)---> [ Signal Server ]
      |                                     ^
      |                                     |
[ Dashboard UI ] <---(HTTPS)--- [ Management Server ] ---> [ Cloud SQL (PostgreSQL) ]
      |                                     |
      +---(OIDC)--- [ Keycloak IdP ] <------+
```

## 2. Core NetBird Components

All core services are deployed via the official NetBird Helm chart and scaled for high availability.

- **Management Server**: The brain of the network. It manages peer identities, network policies, and distributes WireGuard configuration. It uses **Cloud SQL** for persistent state.
- **Signal Server**: Facilitates peer-to-peer connection negotiation. Peers use this to find each other's public endpoints.
- **Relay Server (Coturn)**: A TURN/STUN server that relays encrypted WireGuard traffic when peers are behind restrictive NATs or firewalls that prevent direct P2P.
- **Dashboard**: The web-based administrative interface for managing users, peers, and access controls.

## 3. Infrastructure Foundation

### Kubernetes (GKE)
- **Namespace Isolation**: All components reside in the `netbird` namespace (configurable).
- **High Availability**: Each service runs with `replica_count = 3` by default, spread across nodes for fault tolerance.
- **Resources**: Defined CPU/Memory requests and limits ensure stability and prevent "noisy neighbor" issues.

### Database (Cloud SQL)
- **Engine**: PostgreSQL 14.
- **Type**: Regional Instance (High Availability) with automatic failover across zones.
- **Backups**: Daily automated backups enabled.
- **Security**: Access is restricted to the GKE cluster IP range.

### Identity Provider (Keycloak)
- **Integration**: NetBird uses OpenID Connect (OIDC) for user authentication.
- **Automation**: Terraform automatically provisions the `netbird` realm, OIDC clients (Dashboard and Management), audience mappers, group mappers, and the `view-users`/`query-users` service account roles required by the Management server. It also creates an initial admin user.

## 4. Networking & Security

### Traffic Routing (Ingress)
- **Ingress Controller**: `ingress-nginx` handles external HTTP(S) and GRPC traffic.
- **TLS/SSL**: `cert-manager` automatically provisions and renews certificates via **Let's Encrypt**.
- **Protocols**:
  - `HTTPS (443)`: Dashboard and Management API.
  - `GRPC`: Signal server and Management GRPC endpoint.
  - `UDP (3478)`: Relay/Coturn traffic.

### Secrets Management
- **Sensitive Data**: Database credentials, OIDC secrets, and encryption keys are stored in **Kubernetes Secrets**.
- **Encryption**: The Management server uses a dedicated encryption key to protect peer configuration in the database.

## 5. State Management

- **Terraform State**: Stored remotely in a **Google Cloud Storage (GCS)** bucket to enable collaboration and state locking.
- **Persistent Volumes**: NetBird Management uses a `PersistentVolumeClaim` (GCE PD) for any local state or configuration caching.

## 6. Observability
- **Logs**: Integrated with Google Cloud Logging (fluentbit).
- **Metrics**: Ready for Prometheus scraping via service annotations (optional).
