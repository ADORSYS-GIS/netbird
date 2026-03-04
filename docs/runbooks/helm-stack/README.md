# NetBird | Runbook Index (Helm Stack)

This directory contains tactical procedures for NetBird infrastructure management, deployment, and incident response.

## Infrastructure Actions
- [**Deployment Runbook**](deployment.md)
  - Complete deployment procedures for the NetBird infrastructure on GKE.
- [**Upgrade Runbook**](upgrade.md)
  - Safety procedures for upgrading NetBird and its components.

## Configuration Actions
- [**Kubernetes Operator Integration**](kubernetes-operator.md)
  - Automating service exposure and HA routing inside the cluster.
- [**Kubernetes Cluster as a NetBird Peer**](kubernetes-cluster-peer.md)
  - Step-by-step guide to joining an external Kubernetes cluster (e.g., k3s) to the NetBird mesh network using the operator.
- [**Keycloak OIDC Integration**](keycloak-integration.md)
  - Deep dive into IdP setup and troubleshooting.
- [**AWS VPC Integration**](aws-vpc-integration.md)
  - Secure access to AWS private resources.

## Administrative Actions
- [**Peer & Access Management**](peer-management.md)
  - Connecting devices and configuring zero-trust ACLs.
- [**User & Identity Management**](user-management.md)
  - Managing users and groups through Keycloak.

## Incident Response
- [**Troubleshooting Runbook**](troubleshooting.md)
  - Diagnosis and resolution for OIDC, Ingress, and Connectivity issues.
