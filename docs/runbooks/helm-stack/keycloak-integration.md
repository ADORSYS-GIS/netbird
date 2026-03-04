# NetBird Keycloak OIDC Integration

**Action Type**: Configuration | **Risk**: Medium | **Ops Book**: [Operations Book](../../operations-book/helm-stack/README.md)

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Terraform Ready**: The `keycloak` provider is configured in `main.tf`.
- [ ] **Admin Credentials**: Keycloak admin user/password are correctly set in `terraform.tfvars`.
- [ ] **Network Connectivity**: GKE/Terraform runner can reach the Keycloak URL.

**STOP IF**: The Keycloak URL is unreachable or if the admin-cli client secret is missing.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Realm & Client Provisioning

Terraform automatically provisions the following resources based on `keycloak.tf`:
1. **NetBird Realm**: Configured with production-grade password and brute-force policies.
2. **Backend Client (`netbird-backend`)**: A confidential client used by the management service for user sync and API authentication.
3. **Dashboard Client (`netbird-dashboard`)**: A public client used for the web dashboard and CLI authentication (PKCE enabled).

### STEP 02 - Audience & Scope Mapping

The integration ensures that tokens issued for the dashboard are valid for the backend:
- **Audience Mapper**: Adds the backend client ID to the dashboard's access token audience.
- **Groups Scope**: Automatically maps user group memberships into the `groups` claim.

### STEP 03 - Service Account Roles

The backend client is granted specific realm-management roles to query users and groups:
- `view-users`, `query-users`, `query-groups`, `view-realm`.

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - Token Audit

```bash
# Obtain a test token for the dashboard client
TOKEN=$(curl -s -X POST \
  "https://<keycloak_url>/realms/netbird/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=netbird-dashboard" \
  -d "username=netbird-admin" \
  -d "password=<admin_password>" \
  -d "scope=openid groups" | jq -r '.access_token')

# Verify the groups and audience claims
echo $TOKEN | cut -d. -f2 | base64 -d | jq '{aud: .aud, groups: .groups}'
```

### V02 - Login Success
Verify that users can log in to the NetBird dashboard and their groups are correctly identified in the **Users** tab.

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### Revert Client Configuration
If a client configuration change breaks authentication:
1. Revert the changes in `keycloak.tf`.
2. Run `terraform apply -auto-approve`.

### R02 - Manual Realm Reversion
If Terraform is unable to reconcile the state, use the Keycloak Admin Console to manually restore the previous client settings or mappers.

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
