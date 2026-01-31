#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-}"
NETBIRD_DOMAIN="${NETBIRD_DOMAIN:-}"
NETBIRD_REALM="${NETBIRD_REALM:-netbird}"
NETBIRD_DEFAULT_USER="${NETBIRD_DEFAULT_USER:-admin}"
NETBIRD_DEFAULT_PASSWORD="${NETBIRD_DEFAULT_PASSWORD:-}"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first (e.g., sudo apt install jq)"
        exit 1
    fi
    
    print_info "All dependencies found"
}

validate_inputs() {
    print_info "Validating inputs..."
    
    if [ -z "$KEYCLOAK_URL" ]; then
        print_error "KEYCLOAK_URL is required"
        echo "Usage: KEYCLOAK_URL=https://keycloak.example.com KEYCLOAK_ADMIN_PASSWORD=password NETBIRD_DOMAIN=netbird.example.com $0"
        exit 1
    fi
    
    if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
        print_error "KEYCLOAK_ADMIN_PASSWORD is required"
        exit 1
    fi
    
    if [ -z "$NETBIRD_DOMAIN" ]; then
        print_error "NETBIRD_DOMAIN is required"
        exit 1
    fi
    
    # Remove all trailing slashes from URL
    while [[ "$KEYCLOAK_URL" == */ ]]; do
        KEYCLOAK_URL="${KEYCLOAK_URL%/}"
    done
    
    # Normalize Realm Name
    NETBIRD_REALM=$(echo "$NETBIRD_REALM" | sed 's|^/||;s|/$||')
    
    print_info "Configuration:"
    echo "  Keycloak URL: $KEYCLOAK_URL"
    echo "  Admin User: $KEYCLOAK_ADMIN_USER"
    echo "  NetBird Domain: $NETBIRD_DOMAIN"
    echo "  Realm Name: $NETBIRD_REALM"
}

get_admin_token() {
    print_info "Authenticating to Keycloak..."
    
    RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KEYCLOAK_ADMIN_USER" \
        -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
        print_error "Failed to reach Keycloak at $KEYCLOAK_URL"
        exit 1
    fi

    ADMIN_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty' 2>/dev/null)
    
    if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
        print_error "Failed to authenticate to Keycloak"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    print_info "Authentication successful"
}

create_realm() {
    print_info "Creating NetBird realm..."
    
    # Check if realm already exists
    RESPONSE=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    EXISTING_REALM=$(echo "$RESPONSE" | jq -r '.realm // empty' 2>/dev/null)
    
    if [ "$EXISTING_REALM" = "$NETBIRD_REALM" ]; then
        print_warning "Realm '$NETBIRD_REALM' already exists, skipping creation"
        return
    fi
    
    RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "'"$NETBIRD_REALM"'",
            "enabled": true,
            "displayName": "NetBird",
            "registrationAllowed": false,
            "loginWithEmailAllowed": true,
            "duplicateEmailsAllowed": false,
            "resetPasswordAllowed": true,
            "editUsernameAllowed": false,
            "bruteForceProtected": true,
            "accessTokenLifespan": 300,
            "ssoSessionIdleTimeout": 1800,
            "ssoSessionMaxLifespan": 36000
        }')
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create realm"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    print_info "Realm created successfully"
}

get_client_id() {
    CLIENT_NAME=$1
    
    RESPONSE=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients?clientId=$CLIENT_NAME" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    CLIENT_UUID=$(echo "$RESPONSE" | jq -r '.[0].id // empty' 2>/dev/null)
    echo "$CLIENT_UUID"
}

create_netbird_client() {
    print_info "Creating/Updating NetBird web client..."
    
    # Check if client already exists
    CLIENT_UUID=$(get_client_id "netbird-client")
    
    CLIENT_DATA='{
        "clientId": "netbird-client",
        "name": "NetBird Web Client",
        "description": "NetBird Dashboard and Web Application",
        "enabled": true,
        "publicClient": true,
        "protocol": "openid-connect",
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": false,
        "redirectUris": [
            "https://'"$NETBIRD_DOMAIN"'/*",
            "https://'"$NETBIRD_DOMAIN"'",
            "http://localhost:53000/*",
            "http://localhost:53000"
        ],
        "webOrigins": [
            "https://'"$NETBIRD_DOMAIN"'",
            "http://localhost:53000",
            "*"
        ],
        "attributes": {
            "pkce.code.challenge.method": "S256",
            "post.logout.redirect.uris": "+"
        }
    }'

    if [ -n "$CLIENT_UUID" ] && [ "$CLIENT_UUID" != "null" ]; then
        print_info "Client 'netbird-client' already exists (ID: $CLIENT_UUID), updating..."
        RESPONSE=$(curl -sS -X PUT "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$CLIENT_DATA")
    else
        print_info "Creating new client 'netbird-client'..."
        RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$CLIENT_DATA")
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create/update NetBird client"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    NETBIRD_CLIENT_ID="netbird-client"
    print_info "NetBird client configured successfully"
    
    # Assign 'api' scope if UUID is available
    if [ -n "$API_SCOPE_UUID" ]; then
        print_info "Assigning 'api' scope to netbird-client..."
        curl -sS -X PUT "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID/default-client-scopes/$API_SCOPE_UUID" \
            -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null
    fi

    configure_client_mappers "$CLIENT_UUID" "netbird-client"
}

configure_client_mappers() {
    local CLIENT_UUID=$1
    local CLIENT_ID=$2
    print_info "Configuring protocol mappers for client $CLIENT_ID..."

    # Check if audience mapper already exists
    local MAPPERS=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
        -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)
    
    if echo "$MAPPERS" | jq -e '.[] | select(.name=="audience")' > /dev/null; then
        print_info "Audience mapper already exists"
    else
        print_info "Adding audience mapper..."
        curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "name": "audience",
                "protocol": "openid-connect",
                "protocolMapper": "oidc-audience-mapper",
                "consentRequired": false,
                "config": {
                    "included.client.audience": "'"$CLIENT_ID"'",
                    "id.token.claim": "false",
                    "access.token.claim": "true"
                }
            }' > /dev/null
    fi

    if echo "$MAPPERS" | jq -e '.[] | select(.name=="groups")' > /dev/null; then
        print_info "Groups mapper already exists"
    else
        print_info "Adding groups mapper..."
        curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "name": "groups",
                "protocol": "openid-connect",
                "protocolMapper": "oidc-group-membership-mapper",
                "consentRequired": false,
                "config": {
                    "full.path": "false",
                    "id.token.claim": "true",
                    "access.token.claim": "true",
                    "claim.name": "groups",
                    "userinfo.token.claim": "true"
                }
            }' > /dev/null
    fi
}

create_api_scope() {
    print_info "Creating 'api' client scope..."
    
    # Check if scope already exists
    local SCOPES=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/client-scopes" \
        -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)
    
    local SCOPE_UUID=$(echo "$SCOPES" | jq -r '.[] | select(.name=="api") | .id // empty' 2>/dev/null)
    
    if [ -n "$SCOPE_UUID" ]; then
        print_info "Client scope 'api' already exists (ID: $SCOPE_UUID)"
    else
        print_info "Creating new client scope 'api'..."
        RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/client-scopes" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "name": "api",
                "protocol": "openid-connect",
                "attributes": {
                    "include.in.token.scope": "true",
                    "display.on.consent.screen": "true"
                }
            }')
        
        # Get the new ID
        sleep 1
        SCOPES=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/client-scopes" \
            -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)
        SCOPE_UUID=$(echo "$SCOPES" | jq -r '.[] | select(.name=="api") | .id // empty' 2>/dev/null)
    fi
    
    API_SCOPE_UUID="$SCOPE_UUID"
}

create_management_client() {
    print_info "Creating NetBird management service account..."
    
    # Check if client already exists
    EXISTING_CLIENT=$(get_client_id "netbird-management")
    
    if [ -n "$EXISTING_CLIENT" ] && [ "$EXISTING_CLIENT" != "null" ]; then
        print_warning "Client 'netbird-management' already exists (ID: $EXISTING_CLIENT)"
        
        # Get existing secret
        SECRET_RESPONSE=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$EXISTING_CLIENT/client-secret" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" 2>/dev/null)
        
        MGMT_CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.value // empty' 2>/dev/null)
        MGMT_CLIENT_ID="netbird-management"
        return
    fi
    
    RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "netbird-management",
            "name": "NetBird Management Service",
            "description": "NetBird Management API Service Account",
            "enabled": true,
            "publicClient": false,
            "protocol": "openid-connect",
            "standardFlowEnabled": false,
            "implicitFlowEnabled": false,
            "directAccessGrantsEnabled": false,
            "serviceAccountsEnabled": true,
            "authorizationServicesEnabled": false
        }')
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create management client"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    # Get the created client UUID
    sleep 2
    CLIENT_UUID=$(get_client_id "netbird-management")
    
    if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
        print_error "Failed to retrieve management client UUID"
        exit 1
    fi
    
    # Get client secret
    SECRET_RESPONSE=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients/$CLIENT_UUID/client-secret" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    MGMT_CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.value // empty' 2>/dev/null)
    
    if [ -z "$MGMT_CLIENT_SECRET" ] || [ "$MGMT_CLIENT_SECRET" = "null" ]; then
        print_error "Failed to retrieve management client secret"
        exit 1
    fi
    
    MGMT_CLIENT_ID="netbird-management"
    print_info "Management service account created successfully"
}

configure_realm_settings() {
    print_info "Configuring realm settings for NetBird..."
    
    # Add user profile attributes if needed
    curl -sS -X PUT "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "loginTheme": "keycloak",
            "accountTheme": "keycloak",
            "adminTheme": "keycloak",
            "emailTheme": "keycloak",
            "internationalizationEnabled": true,
            "supportedLocales": ["en"],
            "defaultLocale": "en"
        }' > /dev/null
    
    print_info "Realm settings configured"
}

create_default_user() {
    print_info "Creating default NetBird user..."
    
    # Generate password if not provided or placeholder used
    if [ -z "$NETBIRD_DEFAULT_PASSWORD" ] || [ "$NETBIRD_DEFAULT_PASSWORD" = "<YOUR_DEFAULT_USER_PASSWORD>" ]; then
        NETBIRD_DEFAULT_PASSWORD=$(openssl rand -base64 12 | tr -d '\n')
        print_info "Generated default user password: $NETBIRD_DEFAULT_PASSWORD"
    fi
    
    # Check if user already exists
    RESPONSE=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/users?username=$NETBIRD_DEFAULT_USER" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    USER_UUID=$(echo "$RESPONSE" | jq -r '.[0].id // empty' 2>/dev/null)
    USER_EXISTS=$(echo "$RESPONSE" | jq -r '.[0].username // empty' 2>/dev/null)
    
    if [ "$USER_EXISTS" = "$NETBIRD_DEFAULT_USER" ]; then
        print_info "User '$NETBIRD_DEFAULT_USER' already exists (ID: $USER_UUID), updating password..."
        
        RESPONSE=$(curl -sS -X PUT "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/users/$USER_UUID/reset-password" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "type": "password",
                "value": "'"$NETBIRD_DEFAULT_PASSWORD"'",
                "temporary": false
            }' 2>/dev/null)
            
        if [ $? -eq 0 ]; then
            print_info "Password updated successfully for user '$NETBIRD_DEFAULT_USER'"
        else
            print_warning "Failed to update password for existing user"
        fi
        return
    fi
    
    RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/users" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "username": "'"$NETBIRD_DEFAULT_USER"'",
            "enabled": true,
            "emailVerified": true,
            "firstName": "NetBird",
            "lastName": "Admin",
            "email": "'"$NETBIRD_DEFAULT_USER"'@'"$NETBIRD_DOMAIN"'",
            "credentials": [{
                "type": "password",
                "value": "'"$NETBIRD_DEFAULT_PASSWORD"'",
                "temporary": false
            }]
        }')
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create default user"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    print_info "Default user '$NETBIRD_DEFAULT_USER' created successfully"
}

generate_secrets() {
    print_info "Generating random secrets for NetBird services..."
    
    MANAGEMENT_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    RELAY_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    TURN_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    TURN_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
    DATASTORE_KEY=$(openssl rand -base64 32 | tr -d '\n')
    
    print_info "Secrets generated"
}

print_configuration() {
    if [ "${OUTPUT_FORMAT:-text}" = "json" ]; then
        # JSON output for CI/CD automation - using jq for safe generation
        jq -n \
            --arg ncid "$NETBIRD_CLIENT_ID" \
            --arg mid "$MGMT_CLIENT_ID" \
            --arg ms "$MGMT_CLIENT_SECRET" \
            --arg nms "$MANAGEMENT_SECRET" \
            --arg rs "$RELAY_SECRET" \
            --arg ts "$TURN_SECRET" \
            --arg tp "$TURN_PASSWORD" \
            --arg dsk "$DATASTORE_KEY" \
            --arg realm "$NETBIRD_REALM" \
            --arg domain "$(echo "$KEYCLOAK_URL" | sed 's|https://||;s|http://||')" \
            --arg authority "$KEYCLOAK_URL/realms/$NETBIRD_REALM" \
            --arg du "$NETBIRD_DEFAULT_USER" \
            --arg dp "$NETBIRD_DEFAULT_PASSWORD" \
            '{
                netbird_client_id: $ncid,
                netbird_idp_mgmt_client_id: $mid,
                netbird_idp_mgmt_client_secret: $ms,
                netbird_management_secret: $nms,
                netbird_relay_secret: $rs,
                netbird_turn_secret: $ts,
                netbird_turn_password: $tp,
                netbird_datastore_encryption_key: $dsk,
                netbird_realm: $realm,
                keycloak_domain: $domain,
                netbird_auth_authority: $authority,
                netbird_default_user: $du,
                netbird_default_password: $dp
            }' > /tmp/keycloak-config.json
        cat /tmp/keycloak-config.json
    else
        # Human-readable output
        echo ""
        echo "========================================"
        echo "  NetBird Keycloak Configuration"
        echo "========================================"
        echo ""
        print_info "Keycloak Configuration:"
        echo "  Realm: $NETBIRD_REALM"
        echo "  Keycloak URL: $KEYCLOAK_URL"
        echo "  Authority URL: $KEYCLOAK_URL/realms/$NETBIRD_REALM"
        echo ""
        print_info "Client Configuration:"
        echo "  Client ID (Web): $NETBIRD_CLIENT_ID"
        echo "  Client ID (Management): $MGMT_CLIENT_ID"
        echo "  Client Secret (Management): $MGMT_CLIENT_SECRET"
        echo ""
        print_info "Default NetBird User:"
        echo "  Username: $NETBIRD_DEFAULT_USER"
        echo "  Password: $NETBIRD_DEFAULT_PASSWORD"
        echo ""
        print_info "NetBird Secrets (save these securely):"
        echo "  Management Secret: $MANAGEMENT_SECRET"
        echo "  Relay Secret: $RELAY_SECRET"
        echo "  TURN Secret: $TURN_SECRET"
        echo "  TURN Password: $TURN_PASSWORD"
        echo "  Datastore Encryption Key: $DATASTORE_KEY"
        echo ""
        print_info "Ansible Configuration:"
        echo ""
        echo "Update your infrastructure/ansible/group_vars/netbird_servers/vars.yml:"
        echo "---"
        echo "netbird_realm: \"$NETBIRD_REALM\""
        echo "keycloak_domain: \"$(echo $KEYCLOAK_URL | sed 's|https://||' | sed 's|http://||')\""
        echo "netbird_auth_authority: \"$KEYCLOAK_URL/realms/$NETBIRD_REALM\""
        echo "netbird_idp_mgmt_client_id: \"$MGMT_CLIENT_ID\""
        echo "netbird_idp_mgmt_client_secret: \"$MGMT_CLIENT_SECRET\""
        echo "netbird_management_secret: \"$MANAGEMENT_SECRET\""
        echo "netbird_relay_secret: \"$RELAY_SECRET\""
        echo "netbird_turn_secret: \"$TURN_SECRET\""
        echo "netbird_turn_password: \"$TURN_PASSWORD\""
        echo "netbird_datastore_encryption_key: \"$DATASTORE_KEY\""
        echo ""
        print_info "Configuration complete!"
        echo "========================================"
    fi
}

main() {
    if [ "${OUTPUT_FORMAT:-text}" != "json" ]; then
        echo "" >&2
        echo "╔════════════════════════════════════════╗" >&2
        echo "║   NetBird Keycloak Setup Script       ║" >&2
        echo "╚════════════════════════════════════════╝" >&2
        echo "" >&2
    fi
    
    check_dependencies
    validate_inputs
    get_admin_token
    create_realm
    create_api_scope
    create_netbird_client
    create_management_client
    create_default_user
    configure_realm_settings
    generate_secrets
    print_configuration
    
    if [ "${OUTPUT_FORMAT:-text}" != "json" ]; then
        echo "" >&2
        print_info "Next steps:"
        echo "  1. Update your Ansible vars.yml file with the configuration above" >&2
        echo "  2. Run the Ansible playbook to deploy NetBird" >&2
    fi
}

main "$@"
