# NetBird Troubleshooting & Incident Response

**Action Type**: Incident Response | **Risk**: Medium | **Ops Book**: [Operations Book](../../operations-book/helm-stack/README.md)

## Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Access Verified**: `kubectl` and GCP console access are confirmed.
- [ ] **Logging Enabled**: `kubectl logs` and GCP Cloud Logging are accessible.
- [ ] **On-Call Aware**: Secondary SRE is notified if this is a P1 production incident.

**STOP IF**: You do not have sufficient permissions to modify GKE or Cloud SQL resources.

</details>

## Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Diagnose OIDC & Keycloak

**Issue: Invalid redirect URI**
- **Symptom**: `invalid_redirect_uri` error during login.
- **Fix**: Check `keycloak.tf` for correct `valid_redirect_uris` and apply changes:
```bash
# Verify the domain in terraform.tfvars
grep "netbird_domain" terraform.tfvars
```

**Issue: 401 Unauthorized (Token Validation)**
- **Fix**: Ensure the audience mapper includes the backend client ID.
```bash
# Check the backend client secret from terraform outputs
terraform output -raw keycloak_backend_client_secret
```

### STEP 02 - Diagnose Certificates & Ingress

**Issue: ACME Challenge Failure**
- **Commands**:
```bash
# Check certificate and challenge status
kubectl get certificates -n netbird
kubectl get challenges -n netbird
```
- **Fix**: Ensure port 80 is open and DNS points to the Ingress LoadBalancer IP.

**Issue: 502/503 Service Unavailable**
- **Commands**:
```bash
# Check pod logs for the management service
kubectl logs -n netbird -l app.kubernetes.io/name=netbird -c management
```

### STEP 03 - Diagnose Connectivity

**Issue: Peers failing to connect**
- **Action**: Run `netbird status` on the client device.
- **Verification**: Ensure outbound TCP 443 and UDP 3478 (STUN) are allowed.

</details>

## Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Service Recovery Validation

```bash
# Ensure all pods are back in Running state
kubectl get pods -n netbird
```

### V02 - Connectivity Confirmation
Verify that at least one peer can successfully authenticate and establish a connection to the Management API.

</details>

## Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### Revert Last Configuration Change
If a recent `terraform apply` caused the issue:
1. Revert the changes in the `.tf` or `.tfvars` files.
2. Run `terraform apply -auto-approve`.

### R02 - Restart Services
```bash
# Force a rollout restart of the NetBird components
kubectl rollout restart deployment -n netbird
```

</details>

**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
