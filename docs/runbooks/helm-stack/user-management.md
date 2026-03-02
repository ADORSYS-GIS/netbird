# 📕 UM01 | NetBird User & Identity Management

**Action Type**: Administration | **Risk**: Low | **Ops Book**: [./operations-book.md](../operations-book.md)

[[_TOC_]]

---

## 01. Pre-Flight Safety Gates

<details open><summary>Execution Checklist & Quorum</summary>

- [ ] **Admin Access**: Keycloak admin credentials from `terraform.tfvars` are available.
- [ ] **Identity Service**: Keycloak URL is reachable and the `netbird` realm is active.
- [ ] **Policy Awareness**: Ensure user creation follows the organization's security and naming policies.

**STOP IF**: The Keycloak administration console is unreachable or the `netbird` realm is missing.

</details>

---

## 02. Step-by-Step Execution

<details open><summary>The "Golden Path" Procedure</summary>

### STEP 01 - Access the Identity Console

1. Navigate to `https://keycloak.example.com/admin` (replace with your actual URL).
2. Login with the credentials defined in your Terraform configuration.
3. Select the **NetBird** realm from the top-left dropdown.

### STEP 02 - Create a New User Account

1. Go to **Users** -> **Add User**.
2. Fill in the **Username**, **Email**, and set **Email Verified** to **ON**.
3. In the **Credentials** tab, click **Set Password**.
4. Set a temporary password and ensure **Temporary** is **ON**.

### STEP 03 - Assign Group Membership

1. While in the User details, navigate to the **Groups** tab.
2. Click **Join Group** and select `netbird-admins` (or other predefined groups).
3. **Note**: Group memberships in Keycloak sync to NetBird upon the user's first login.

</details>

---

## 03. Verification & Acceptance

<details open><summary>Post-Action Hardening</summary>

### V01 - User Login Test
Ask the user to log in at `https://netbird.example.com` and verify they are prompted to change their password.

### V02 - NetBird Sync Verification
1. Access the NetBird Dashboard as an admin.
2. Go to **Users** and verify the new user appears in the list with the correct groups.

### V03 - Token Audit (Optional)
```bash
# Verify the groups claim in the access token
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq '.groups'
```

</details>

---

## 04. Emergency Rollback (The Panic Button)

<details><summary>Rollback Instructions</summary>

### R01 - Account Disabling
If a user was created in error or represents a security risk:
1. In Keycloak Admin, go to the User's details.
2. Set **Enabled** to **OFF**.
3. In the **Sessions** tab, click **Logout all sessions**.

### R02 - Account Deletion
Go to **Users**, search for the user, and click **Delete User**.

</details>

---
**Metadata & Revision History**
- **Created**: 2026-02-27
- **Version**: 1.0.0
- **Author**: NetBird DevOps Team
