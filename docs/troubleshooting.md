# Troubleshooting Guide

Common issues and solutions for the NetBird Terraform + Helm deployment.

---

## OIDC / Keycloak Errors

### Invalid redirect URI
**Symptom**: `invalid_redirect_uri` error after login  
**Fix**: Ensure `valid_redirect_uris` in `keycloak.tf` includes your dashboard URL:
```
https://<netbird_domain>/*
https://<netbird_domain>/auth
https://<netbird_domain>/silent-auth
http://localhost:53000/*
```

### Token validation fails (`invalid_token` or `401 Unauthorized`)
**Fix**:
1. Verify `NB_AUTH_AUDIENCE` matches the backend client ID (`netbird-backend`)
2. Check the audience mapper exists: Keycloak Admin → NetBird Dashboard client → Mappers → `netbird-backend-audience`
3. Confirm token includes the `groups` claim: decode a JWT at [jwt.io](https://jwt.io)

### Client secret mismatch
**Fix**: Run `terraform output -raw keycloak_backend_client_secret` and compare with the secret in `netbird-secrets` K8s Secret.

---

## Certificate Issues

### cert-manager not issuing certificates
```bash
# Check ClusterIssuer status
kubectl get clusterissuer letsencrypt-prod -o yaml

# Check certificate status
kubectl get certificates -n netbird -o wide

# Check challenge status
kubectl get challenges -A -o wide
```

### ACME challenge failing
**Common causes**:
- DNS not pointing to the ingress LoadBalancer IP
- Port 80 blocked (HTTP-01 challenge needs it)
- `ingress_class_name` doesn't match installed ingress controller

### RBAC permission denied on Certificate resources
**Fix**: Ensure the RBAC `ClusterRole` grants access to cert-manager CRDs:
```bash
kubectl auth can-i create certificates.cert-manager.io -n netbird --as=system:serviceaccount:netbird:default
```

---

## Ingress Issues

### DNS not resolving
```bash
# Get the LoadBalancer external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Verify DNS resolution
dig +short <netbird_domain>
```
Create an A record pointing your domain to the external IP.

### 502 Bad Gateway / 503 Service Unavailable
```bash
# Check pod status
kubectl get pods -n netbird

# Check pod logs
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-management
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-signal
```

### gRPC protocol errors (signal / management gRPC)
**Fix**: Ensure ingress-nginx has HTTP/2 enabled:
```bash
kubectl get configmap -n ingress-nginx ingress-nginx-controller -o jsonpath='{.data.use-http2}'
```
Should return `true`. The Terraform config sets this automatically when `install_ingress_nginx = true`.

---

## NetBird Connectivity

### Signal unreachable
```bash
# Test signal gRPC endpoint
grpcurl -insecure <netbird_domain>:443 list

# Check signal pod
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-signal
```

### Relay issues
```bash
# Check relay pod
kubectl logs -n netbird -l app.kubernetes.io/name=netbird-relay

# Verify relay auth secret matches
kubectl get secret netbird-secrets -n netbird -o jsonpath='{.data.relay_password}' | base64 -d
```

### Peers not connecting
1. Verify management URL: `netbird status`
2. Check firewall: outbound TCP 443 must be open
3. Test STUN: `stun stun.l.google.com:19302`

---

## Helm Deployment

### Pod CrashLoopBackOff
```bash
# Check events
kubectl describe pod -n netbird <pod-name>

# Check logs
kubectl logs -n netbird <pod-name> --previous
```
Common causes: missing secrets, invalid management config, database connection failure.

### PVC Pending (SQLite mode)
```bash
kubectl get pvc -n netbird
kubectl describe pvc -n netbird <pvc-name>
```
Ensure a storage class exists and can provision volumes.

---

## Keycloak Configuration

### Groups not appearing in tokens
1. Check scope: Keycloak Admin → Client Scopes → `groups` → verify mapper exists
2. Check assignment: Keycloak Admin → NetBird Dashboard client → Client Scopes → verify `groups` is in Default Scopes
3. Test: get a token and decode it — look for `"groups": [...]` claim

### Admin user login fails
- Verify email is verified: Keycloak Admin → Users → netbird-admin → `Email Verified = ON`
- Check password meets policy (12 chars, upper, lower, digit, special)
- Check brute-force: Keycloak Admin → Realm Settings → Security → Brute Force Detection

---

## Terraform State

### State lock errors
```bash
terraform force-unlock <LOCK_ID>
```

### Provider migration (`mrparkers/keycloak` → `keycloak/keycloak`)
If upgrading from the old provider:
```bash
terraform state replace-provider mrparkers/keycloak keycloak/keycloak
```
