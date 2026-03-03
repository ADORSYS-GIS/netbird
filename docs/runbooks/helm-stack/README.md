# 📕 NetBird | Runbook Index

This directory contains tactical procedures for NetBird infrastructure management, deployment, and incident response.

[[_TOC_]]

---

## 01. Infrastructure Actions
- [**D01 | Deployment Runbook**](deployment.md)
  - Complete deployment procedures for the NetBird infrastructure on GKE.
- [**U01 | Upgrade Runbook**](upgrade.md)
  - Safety procedures for upgrading NetBird and its components.

## 02. Configuration Actions
- [**KO01 | Kubernetes Operator Integration**](kubernetes-operator.md)
  - Automating service exposure and HA routing inside the cluster.
- [**KC01 | Kubernetes Cluster as a NetBird Peer**](kubernetes-cluster-peer.md)
  - Step-by-step guide to joining an external Kubernetes cluster (e.g., k3s) to the NetBird mesh network using the operator.
- [**KI01 | Keycloak OIDC Integration**](keycloak-integration.md)
  - Deep dive into IdP setup and troubleshooting.
- [**AI01 | AWS VPC Integration**](aws-vpc-integration.md)
  - Secure access to AWS private resources.

## 03. Administrative Actions
- [**PM01 | Peer & Access Management**](peer-management.md)
  - Connecting devices and configuring zero-trust ACLs.
- [**UM01 | User & Identity Management**](user-management.md)
  - Managing users and groups through Keycloak.

## 04. Incident Response
- [**TS01 | Troubleshooting Runbook**](troubleshooting.md)
  - Diagnosis and resolution for OIDC, Ingress, and Connectivity issues.

---
*Last Updated: 2026-03-03*
