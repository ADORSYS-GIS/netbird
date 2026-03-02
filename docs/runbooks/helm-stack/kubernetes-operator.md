# 📕 KO01 | NetBird Kubernetes Operator Integration

**Action Type**: Configuration | **Risk**: Medium | **Ops Book**: [./operations-book.md](../operations-book.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Cluster Health**: GKE cluster is stable and `kubectl` access is confirmed.
- [ ] **NetBird Management**: The management server is reachable at the configured URL.
- [ ] **Setup Key**: A valid NetBird setup key is stored in a Kubernetes secret.

**STOP IF**: The management server is down or if the setup key is expired/invalid.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Operator Deployment

The operator is deployed as part of the Helm release. It watches for changes in Kubernetes services and namespaces to automate peer registration and routing.

### STEP 02 - Resource Annotation

To expose a Kubernetes service to the NetBird mesh, add the following annotation to your service manifest:
```yaml
metadata:
  annotations:
    netbird.io/expose: "true"
```
The operator will detect this and automatically create a route in NetBird Management.

### STEP 03 - HA Routing Peer Configuration

For production high-availability, configure the operator to use multiple routing peers:
1. Set `replicas: 2` in the `NetbirdConfig` CRD.
2. Implement pod anti-affinity to ensure routing peers are scheduled on different physical nodes.

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Operator Logs Verification

```bash
# Check the operator logs for successful synchronization
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-operator
```

### V02 - Route Propagation Test
Verify that the annotated service appears as a route in the NetBird Dashboard under **Network Routes**.

### V03 - Connectivity Check
From an external peer, attempt to reach the Kubernetes service using its assigned NetBird IP or DNS name.

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### R01 - Annotation Removal
Remove the `netbird.io/expose` annotation from the Kubernetes service to trigger route deletion in NetBird Management.

### R02 - Operator Restart
```bash
# Force a restart of the operator controller
kubectl rollout restart deployment netbird-operator -n netbird
```

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
