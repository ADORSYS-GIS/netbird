# Kubernetes Cluster as a NetBird Peer

**Action Type**: Configuration | **Risk**: Medium | **Ops Book**: [../operations-book/README.md](../operations-book/README.md)

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **NetBird Management**: The management server is online and reachable at `https://netbird.net.observe.camer.digital`.
- [ ] **Target Cluster Access**: `kubectl get nodes` succeeds against the target Kubernetes cluster (e.g., k3s).
- [ ] **Helm 3.x Installed**: `helm version` returns a valid version on the target cluster's host.
- [ ] **cert-manager**: cert-manager is installed on the target cluster — required by the operator's webhook.
- [ ] **PAT Token**: A Personal Access Token (PAT) scoped to the self-hosted management server exists.
- [ ] **Setup Key**: A reusable setup key is created in the NetBird Dashboard under **Setup Keys**.

**STOP IF**: The management server is unreachable or cert-manager is not running on the target cluster.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 — Add the NetBird Helm Repository

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml   # adjust for your cluster

helm repo add netbirdio https://netbirdio.github.io/kubernetes-operator
helm repo update
```

### STEP 02 — Create the Operator Namespace

```bash
kubectl create namespace netbird
```

### STEP 03 — Store the PAT in a Kubernetes Secret

Generate a PAT from the self-hosted dashboard:  
**Dashboard → Settings → Personal Access Tokens → Add Token**

```bash
kubectl create secret generic netbird-mgmt-api-key \
  --namespace netbird \
  --from-literal=NB_API_KEY=<your-pat-token>
```

> **Important**: The PAT must be generated from the self-hosted management server (`https://netbird.net.observe.camer.digital`), not from `app.netbird.io`.

### STEP 04 — Store the Setup Key in a Kubernetes Secret

Create a reusable setup key in the NetBird Dashboard under **Setup Keys**, then:

```bash
kubectl create secret generic netbird-setup-key \
  --namespace netbird \
  --from-literal=key=<your-setup-key-uuid>
```

### STEP 05 — Install the NetBird Kubernetes Operator

```bash
helm upgrade --install netbird-operator netbirdio/kubernetes-operator \
  --namespace netbird \
  --set managementURL=https://netbird.net.observe.camer.digital \
  --set netbirdAPI.keyFromSecret.name=netbird-mgmt-api-key \
  --set netbirdAPI.keyFromSecret.key=NB_API_KEY \
  --set cluster.name=<your-cluster-name>
```

| Parameter | Description |
|-----------|-------------|
| `managementURL` | Full URL of the self-hosted management server |
| `netbirdAPI.keyFromSecret.name` | Name of the secret holding the PAT |
| `netbirdAPI.keyFromSecret.key` | Key within that secret |
| `cluster.name` | Logical name for this cluster in NetBird |

### STEP 06 — Install the Operator Config Chart

The `netbird-operator-configs` chart creates the `NBRoutingPeer` custom resource that registers the cluster as a routing peer.

```bash
helm upgrade --install netbird-config netbirdio/netbird-operator-configs \
  --namespace netbird \
  --set managementURL=https://netbird.net.observe.camer.digital \
  --set setupKey=<your-setup-key-uuid> \
  --set router.enabled=true \
  --set router.replicas=1 \
  --set kubernetesAPI.enabled=true \
  --set "kubernetesAPI.groups[0]=all"
```

| Parameter | Description |
|-----------|-------------|
| `setupKey` | UUID of the reusable setup key |
| `router.enabled` | Deploys routing peer pods into the cluster |
| `router.replicas` | Number of routing peer replicas (1 for single-node clusters) |
| `kubernetesAPI.enabled` | Exposes the Kubernetes API via NetBird |
| `kubernetesAPI.groups` | NetBird groups that can access the cluster |

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 — Operator and Router Pods Running

```bash
kubectl get pods -n netbird

# Expected Output:
# netbird-operator-kubernetes-operator-xxx   1/1   Running
# router-xxxxxxxxxx-xxx                      1/1   Running
```

### V02 — Operator Using the Correct Management URL

```bash
kubectl get deployment netbird-operator -n netbird \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n'

# Expected to contain:
# --netbird-management-url=https://netbird.net.observe.camer.digital
```

### V03 — NBRoutingPeer Status is Ready

```bash
kubectl get nbroutingpeer -n netbird -o yaml

# Expected status:
# conditions:
# - status: "True"
#   type: Ready
# networkID: <id>
# routerID: <id>
```

### V04 — Cluster Appears as Peer in Dashboard

Navigate to **Dashboard → Peers**. The cluster's router pod(s) should appear as connected peers with a NetBird IP in the `100.64.x.x` range.

### V05 — Operator Logs Show No Errors

```bash
kubectl logs -n netbird -l app.kubernetes.io/name=kubernetes-operator --tail=50
```

Look for successful reconciliation messages and absence of `token invalid` or `connection refused` errors.

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### Remove Operator Config (Routing Peer)

```bash
helm uninstall netbird-config -n netbird
```

This removes the `NBRoutingPeer` CR and triggers the operator to delete the peer and its associated routes from NetBird Management.

### R02 — Remove the Operator

```bash
helm uninstall netbird-operator -n netbird
```

### R03 — Clean Up Secrets

```bash
kubectl delete secret netbird-mgmt-api-key netbird-setup-key -n netbird
```

### R04 — Remove the Namespace

```bash
kubectl delete namespace netbird
```

### R05 — Remove Peer from Dashboard

If the peer remains listed after operator removal, navigate to **Dashboard → Peers**, select the stale router peer(s), and click **Delete**.

</details>

---

## 05. Day-2 Operations

<details><summary>Common Post-Deployment Tasks</summary>

### Adjusting Router Replica Count

```bash
helm upgrade netbird-config netbirdio/netbird-operator-configs \
  --namespace netbird \
  --reuse-values \
  --set router.replicas=3
```

### Rotating the PAT Token

1. Generate a new PAT from the NetBird Dashboard.
2. Update the secret:
```bash
kubectl create secret generic netbird-mgmt-api-key \
  --namespace netbird \
  --from-literal=NB_API_KEY=<new-pat-token> \
  --dry-run=client -o yaml | kubectl apply -f -
```
3. Restart the operator to pick up the new secret:
```bash
kubectl rollout restart deployment netbird-operator -n netbird
```

### Checking Stuck Resource Finalizers

If an `NBRoutingPeer` is stuck in `Terminating` with a finalizer blocking deletion:

```bash
kubectl patch nbroutingpeer router -n netbird \
  -p '{"metadata":{"finalizers":[]}}' --type=merge
```

</details>

---

**Metadata & Revision History**
- **Created**: 2026-03-03
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team

---
