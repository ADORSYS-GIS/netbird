# Terraform Module: Keycloak Realm for NetBird

## Overview
This Terraform configuration provisions a Keycloak realm and companion resources aligned with the Ansible-based NetBird deployment. It creates:

- Realm `var.keycloak_realm` (e.g., `netbird`)
- Confidential OIDC client for NetBird Dashboard/Management API
- Groups matching `var.keycloak_groups`
- Group membership protocol mapper to expose groups in ID/Access tokens

Use this module when you prefer declarative, idempotent realm configuration managed alongside infrastructure code.

## Requirements
- **Terraform** 1.5+
- **Keycloak Provider** (`MrPorter/keycloak` ~> 4.1)
- Admin credentials with realm management privileges (typically `master` realm admin)
- Network access to Keycloak HTTPS endpoint

## Inputs
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `keycloak_base_url` | string | — | Base URL of Keycloak (`https://keycloak.localhost`) |
| `keycloak_tls_insecure` | bool | `true` | Skip TLS verification (set to false in production) |
| `keycloak_admin_client_id` | string | `admin-cli` | Admin client ID |
| `keycloak_admin_client_secret` | string | `""` | Optional secret for admin client |
| `keycloak_admin_username` | string | — | Admin username |
| `keycloak_admin_password` | string | — | Admin password |
| `keycloak_realm` | string | — | Realm name |
| `keycloak_realm_display_name` | string | `NetBird Realm` | Realm display name |
| `keycloak_client_id` | string | — | NetBird OIDC client ID |
| `keycloak_client_secret` | string | — | NetBird client secret |
| `keycloak_client_root_url` | string | — | NetBird dashboard base URL |
| `keycloak_client_redirect_uris` | list(string) | — | Allowed redirect URIs |
| `keycloak_groups` | list(object) | `[]` | Groups to ensure exist |

## Usage Example
```hcl
module "keycloak_netbird" {
  source = "./terraform/keycloak"

  keycloak_base_url            = "https://keycloak.localhost"
  keycloak_admin_username      = "admin"
  keycloak_admin_password      = "changeme"
  keycloak_realm               = "netbird"
  keycloak_client_id           = "netbird-client"
  keycloak_client_secret       = "supersecret"
  keycloak_client_root_url     = "https://netbird.localhost"
  keycloak_client_redirect_uris = [
    "https://netbird.localhost/auth/callback",
    "https://netbird.localhost/api/oidc/callback"
  ]
  keycloak_groups = [
    { name = "engineering", description = "Engineering team" },
    { name = "operations", description = "Operations team" }
  ]
}
```

Run:
```bash
terraform init
terraform apply
```

## Notes
- Disable `keycloak_tls_insecure` for production deployments and trust the CA instead.
- To manage more complex realm features (IDP federation, clients, roles, etc.), extend this module or create additional Terraform resources.
- Keep secrets in a secure store or use Terraform Cloud/Enterprise variable management.