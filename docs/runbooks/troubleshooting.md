# Infrastructure Troubleshooting Guide

This guide serves as a central hub for diagnosing and resolving issues across different NetBird deployment stacks.

## Stack-Specific Troubleshooting

### Helm Stack (Kubernetes/GKE)
- [**Helm Troubleshooting**](./helm-stack/troubleshooting.md)
  - *Covers: Pod failures, Ingress issues, Cert-manager errors, and GKE connectivity.*

### Ansible Stack (VMs/Docker)
- [**Ansible Troubleshooting**](./ansible-stack/troubleshooting-restoration.md)
  - *Covers: Docker Compose issues, HAProxy failover, and VM-level network problems.*

## Global Diagnostics

### 1. Management API Health
Regardless of the stack, the management API should be accessible at its health endpoint:
```bash
curl -f https://<your-netbird-domain>/health
```

### 2. Client Connectivity
Peers having trouble connecting should check their local status:
```bash
netbird status
```

### 3. Log Analysis
- **Helm**: `kubectl logs -n netbird -l app.kubernetes.io/name=netbird`
- **Ansible**: `docker logs netbird-management`
