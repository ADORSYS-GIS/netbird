# NetBird Access Control Configuration Tutor

## 1. Implement a Default-Deny ACL

1. **Sign in to the dashboard**
   - Browse to `https://<your-netbird-domain>` and authenticate with your SSO/Keycloak credentials.
2. **Open the policy workspace**
   - In the left sidebar, select `Access Control`, then click `Policies` to display the current rule list.
3. **Create the baseline policy**
   - Press **+ Create Policy**.
   - Name it `Default Deny All` (or similar) and add an optional description such as "Baseline deny-all policy to block all traffic by default".
4. **Define the rule**
   - Set **Sources** to `All Peers` (or use the `*` wildcard).
   - Set **Destinations** to `All Peers`.
   - Set **Ports/Protocols** to `All` unless you need to limit to specific protocols.
   - Choose **Action → Deny** (or **Drop**) if available, then click **Add Rule**.
5. **Understand the implicit deny model**
   - **Note**: Some NetBird releases only offer an "Accept" action. In that case, rely on NetBird's implicit default-deny behavior by omitting broad allow rules. Only explicitly allowed traffic will be permitted.
6. **Activate and order the policy**
   - Click **Save** to enable the policy.
   - Place it appropriately in the list: if policies are evaluated top-down, position specific allow rules above the deny; if evaluation is bottom-up, keep the deny at the bottom. Consult the UI helper text for confirmation.
7. **Validate the baseline**
   - Enroll a test peer and confirm that it cannot reach any other peer until you add explicit allow policies.

## 2. Define Granular, Least-Privilege Access Rules

1. **Assign identity-driven groups**
   - Go to `Peers` in the sidebar.
   - For each peer, use **Assign Tag/Group** to align it with functional groups such as `web-servers`, `db-servers`, `devs`, or `ops`.
   - Create new tags on the fly if they do not exist.
2. **Describe target services**
   - Map the resources you intend to expose (for example, `web-servers` on TCP 443 or `db-servers` on TCP 5432).
   - NetBird policies reference destination groups and ports directly, so separate service objects are optional.
3. **Author least-privilege policies**
   - Navigate back to `Access Control → Policies` and click **+ Create Policy**.
   - Specify:
     - **Source Group**: the requesting group (e.g., `devs`).
     - **Destination Group**: the service group (e.g., `web-servers`).
     - **Protocol**: `TCP`, `UDP`, or both.
     - **Ports**: the minimal port list required (e.g., `443`).
     - **Action**: `Accept`.
   - Example policy: "Allow `devs` → `web-servers` on TCP port 443".
4. **Prioritize specific rules**
   - Order detailed rules (narrow groups and ports) above broader ones to avoid unintended access.
   - Keep extraneous wide-open rules out of the policy set; everything else will remain blocked.
5. **Test the outcome**
   - From a device in `devs`, confirm you can reach the intended web server on port 443 but are denied when accessing other services like databases.

## 3. Configure Split Tunneling and Per-Group DNS Settings

### 3.1 DNS Profiles

1. **Open the DNS panel**
   - In the sidebar, select `Network → DNS` (sometimes labeled `Nameservers`).
2. **Create a DNS profile**
   - Click **Add DNS Profile** (or **Add Nameserver**).
   - Provide a descriptive name such as `Office Internal DNS`.
   - Enter the DNS server IP(s) and optional ports.
3. **Attach match domains (optional)**
   - For split DNS, specify match domains—for example, `*.internal.company.com`—so only those queries use the internal resolver.
   - **Note**: Match domains require compatible client OS support (macOS, Windows 10+, or Linux with `systemd-resolved`).
4. **Distribute to groups**
   - Choose the groups that should receive the profile (e.g., `devs`, `ops`).
   - Save the configuration and confirm that peers in those groups resolve internal domains via the assigned servers.

### 3.2 Split-Tunnel Routing

1. **Designate routing peers**
   - In `Peers`, edit the node that will provide Internet egress and enable the `Exit Node` (or `Routing Peer`) setting.
2. **Control full-tunnel vs. split-tunnel**
   - For groups needing full-tunnel access, enable use of the exit node or push the default route (`0.0.0.0/0`).
   - For split-tunnel groups, leave the default route disabled so only internal prefixes traverse NetBird.
3. **Publish internal routes**
   - Navigate to `Network → Routes`.
   - Click **Add Route** and define internal CIDRs (e.g., `10.10.0.0/16`).
   - Assign these routes to the relevant groups.
4. **Verify behavior**
   - From a split-tunnel client, access internal services (should succeed) and check public websites (should exit via local ISP).
   - Confirm DNS queries for internal zones use the internal resolver, while public domains use the external resolver.

## 4. Enforce SSO/OIDC for User Authentication

1. **Prepare Keycloak mappings**
   - In the Keycloak Admin Console, ensure users belong to the correct groups or roles.
   - Configure protocol mappers for the NetBird client so group claims are embedded in the issued tokens.
2. **Set NetBird authentication parameters**
   - Ensure the management configuration (for example, `setup.env` or `management.json`) includes the OIDC discovery URL, client ID, client secret, scopes, and audience values.
3. **Enable SSO in the dashboard**
   - In the NetBird dashboard, open `Settings → Authentication` (or the equivalent section).
   - Confirm `Enable SSO/OIDC` is toggled on, and disable any local password logins if the UI offers that option.
4. **Validate the login flow**
   - Sign out of NetBird, then sign back in.
   - Verify you are redirected to Keycloak and, after authentication, returned to NetBird with the appropriate access level.
   - Attempt an action that should be restricted for your role to ensure enforcement works.

## 5. Establish a WireGuard Key Rotation Process

1. **Inventory peers and sensitivity**
   - In the `Peers` view, tag or note peers that handle sensitive workloads so you can prioritize their key rotations.
2. **Check rotation capabilities**
   - Determine whether your NetBird version or API allows regenerating peer keys in place; if not, plan for peer reprovisioning.
3. **Run controlled rotation**
   - Use the NetBird CLI or API (`netbird peer rotate-keys`) to issue new keys.
   - Keep downtime minimal by overlapping old and new keys when supported.
4. **Automate the schedule**
   - Define a rotation interval (e.g., every 60–90 days) and enforce it via cron, CI, or ticket reminders.
5. **Monitor and audit**
   - After each rotation, review peer connectivity and logs for failed handshakes.
   - Maintain an audit trail of key changes, including who initiated the rotation and when.