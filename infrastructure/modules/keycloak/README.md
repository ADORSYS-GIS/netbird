# Keycloak Module

Configures Keycloak realm and clients for NetBird SSO authentication.

## Features

- Creates or uses existing Keycloak realm
- Configures public client for dashboard/CLI
- Configures confidential client for management API
- Sets up required scopes and mappers
- Creates default admin user

## Usage

```hcl
module "keycloak" {
  source = "../modules/keycloak"

  keycloak_url            = "https://keycloak.example.com"
  keycloak_admin_username = "admin"
  keycloak_admin_password = var.keycloak_password
  realm_name              = "netbird"
  use_existing_realm      = false
  netbird_domain          = "vpn.example.com"
  netbird_admin_email     = "admin@example.com"
  netbird_admin_password  = var.admin_password
}
```

## Outputs

- `client_id` - Public client ID for dashboard
- `backend_client_id` - Confidential client ID for API
- `backend_client_secret` - Client secret for API
- `issuer_url` - OIDC issuer URL
