# NetBird & Keycloak Security Configuration Guide

## Overview
This guide walks through configuring a self-hosted NetBird deployment that uses Keycloak as the identity provider (IdP). It covers enforcing SSO/OIDC authentication, establishing a default-deny access control baseline with least-privilege rules, enabling split tunneling with per-group DNS, and implementing an ongoing WireGuard key rotation process.

## Prerequisites
- **NetBird Control Plane**: Installed and reachable via HTTPS with administrative access.
- **Keycloak Realm**: Configured with authority to create clients, mappers, and assign groups.
- **Administrative Permissions**: Ability to modify NetBird policies, groups, DNS settings, and automation scripts.
- **Managed Hosts**: NetBird agents installed on all participating endpoints with network connectivity to the control plane.

## 1. Enforce SSO/OIDC with Keycloak
1. **Create NetBird Client in Keycloak**
   1. Navigate to **Clients → Create** and choose *OpenID Connect confidential*.
   2. Set valid redirect URIs, for example `https://<netbird-domain>/auth/callback` and any additional admin endpoints.
   3. Assign the standard scopes `openid` and `profile`, plus a custom scope or mapper that exposes the user's groups (e.g., `groups`).
   4. Generate a client secret that NetBird will use for backend-to-backend communication.
2. **Configure NetBird to Trust Keycloak**
   1. In the NetBird dashboard, open the identity provider configuration page.
   2. Set the issuer URL to `https://<keycloak-domain>/realms/<realm>`.
   3. Enter the Keycloak client ID and secret created earlier.
   4. Map the Keycloak `groups` claim to NetBird group assignments to keep access synchronized.
   5. Disable local login options to force all users through Keycloak SSO.
3. **Validate the Authentication Flow**
   1. Log out of NetBird and attempt to sign in again.
   2. Confirm the Keycloak login screen appears and completes successfully.
   3. Verify that the returned user is automatically placed into the expected NetBird groups based on Keycloak claims.

## 2. Establish a Default-Deny ACL Baseline
1. **Create a Global Deny Policy**
   1. Open the NetBird policies section and add a policy named `Default Deny`.
   2. Set **Action** to `deny`, **Source** to `*`, and **Destination** to `*` so all peer-to-peer traffic is blocked.
   3. Enable the policy and move it to the top of the evaluation order to ensure it executes first.
2. **Confirm the Baseline**
   1. Attempt a connection between two peers; it should now fail by default.
   2. Note that no traffic will succeed until explicit allow rules are introduced beneath this baseline.

## 3. Define Least-Privilege Group Rules
1. **Organize Groups in Keycloak**
   1. Create or update Keycloak groups reflecting real-world roles (e.g., `engineering`, `operations`, `support`).
   2. Place users into their appropriate groups so the `groups` claim represents desired access levels.
2. **Mirror Groups and Resources in NetBird**
   1. In NetBird, create user groups that correspond to Keycloak roles if they are not auto-synced.
   2. Group hosts or services into resource groups (e.g., `svc-database`, `svc-ci-runner`) for granular targeting.
3. **Create Allow Policies for Required Access**
   1. For each needed interaction, add a policy with **Action** `allow`, **Source** set to a user group, and **Destination** set to a resource group.
   2. Restrict **Protocol** and **Port** fields when possible to limit the traffic surface.
   3. Document the justification for each policy in its description to support future audits.
4. **Test Group-Based Access**
   1. Use NetBird's connection tester or manually connect between peers to ensure allowed paths function.
   2. Confirm that users outside the authorized groups continue to be blocked by the default-deny policy.

## 4. Configure Split Tunneling and Per-Group DNS
1. **Design Split Tunneling Routes**
   1. Identify internal subnets that should traverse NetBird (e.g., `10.10.0.0/16`).
   2. In NetBird, assign custom routes to specific groups so only necessary traffic is tunneled.
   3. Leave other traffic (such as general internet browsing) outside the tunnel for performance and privacy.
2. **Set Per-Group DNS Servers**
   1. Define DNS servers and search domains per group within NetBird (e.g., `10.0.0.10` with search domain `corp.internal` for `engineering`).
   2. Configure fallback DNS servers for general users if corporate DNS access is not required.
3. **Verify Client Behavior**
   1. On a client machine, inspect routing tables to ensure only defined prefixes route through NetBird.
   2. Use tools such as `dig` or `nslookup` to confirm DNS queries resolve through the assigned servers.

## 5. Implement Regular WireGuard Key Rotation
1. **Define the Rotation Cadence**
   1. Choose a rotation interval (e.g., every 30 days) that aligns with security requirements and maintenance windows.
2. **Automate Key Rotation**
   1. Schedule an automation task (cron job, CI pipeline, or configuration management tool) to trigger NetBird key rotation.
   2. Use a command similar to the one below for rotating all peers:
      ```bash
      # Rotate all WireGuard keys to maintain cryptographic hygiene
      netbird peer rotate-keys --all
      ```
   3. Optionally iterate through specific groups if certain peers require a different schedule.
3. **Communicate and Monitor**
   1. Notify stakeholders ahead of time about potential brief interruptions during key rotations.
   2. Review NetBird logs or dashboards after each rotation to confirm success and address any failures promptly.

## Ongoing Maintenance and Auditing
1. **Policy Reviews**
   1. Conduct quarterly reviews of ACLs, group memberships, and resource assignments to maintain least privilege.
2. **Security Monitoring**
   1. Export NetBird audit logs to a SIEM or log aggregation platform to track denied access attempts and anomalous behavior.
3. **Backup and Recovery**
   1. Regularly back up NetBird configuration (policies, groups, routes) and Keycloak realm settings.
   2. Document and practice restoration procedures to ensure rapid recovery from outages or misconfigurations.

By following this tutorial, your NetBird mesh will enforce Keycloak-backed SSO, default-deny network segmentation, tightly scoped access controls, controlled routing, and consistent key rotation, providing a robust security posture for your self-hosted deployment.