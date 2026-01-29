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

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    
    # Remove trailing slash from URL
    KEYCLOAK_URL="${KEYCLOAK_URL%/}"
    
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
        -d "client_id=admin-cli" 2>&1)
    
    ADMIN_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty')
    
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
    EXISTING_REALM=$(curl -sS -X GET "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.realm // empty')
    
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
        -H "Content-Type: application/json")
    
    CLIENT_UUID=$(echo "$RESPONSE" | jq -r '.[0].id // empty')
    echo "$CLIENT_UUID"
}

create_netbird_client() {
    print_info "Creating NetBird web client..."
    
    # Check if client already exists
    EXISTING_CLIENT=$(get_client_id "netbird-client")
    
    if [ -n "$EXISTING_CLIENT" ] && [ "$EXISTING_CLIENT" != "null" ]; then
        print_warning "Client 'netbird-client' already exists (ID: $EXISTING_CLIENT)"
        NETBIRD_CLIENT_ID="netbird-client"
        return
    fi
    
    RESPONSE=$(curl -sS -X POST "$KEYCLOAK_URL/admin/realms/$NETBIRD_REALM/clients" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
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
                "http://localhost:53000/*"
            ],
            "webOrigins": [
                "https://'"$NETBIRD_DOMAIN"'",
                "http://localhost:53000"
            ],
            "attributes": {
                "pkce.code.challenge.method": "S256"
            }
        }')
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create NetBird client"
        echo "Response: $RESPONSE"
        exit 1
    fi
    
    NETBIRD_CLIENT_ID="netbird-client"
    print_info "NetBird client created successfully"
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
            -H "Content-Type: application/json")
        
        MGMT_CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.value // empty')
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
        -H "Content-Type: application/json")
    
    MGMT_CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.value // empty')
    
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
        # JSON output for CI/CD automation
        cat > /tmp/keycloak-config.json <<EOF
{
  "netbird_client_id": "$NETBIRD_CLIENT_ID",
  "netbird_idp_mgmt_client_id": "$MGMT_CLIENT_ID",
  "netbird_idp_mgmt_client_secret": "$MGMT_CLIENT_SECRET",
  "netbird_management_secret": "$MANAGEMENT_SECRET",
  "netbird_relay_secret": "$RELAY_SECRET",
  "netbird_turn_secret": "$TURN_SECRET",
  "netbird_turn_password": "$TURN_PASSWORD",
  "netbird_datastore_encryption_key": "$DATASTORE_KEY",
  "netbird_realm": "$NETBIRD_REALM",
  "keycloak_domain": "$(echo $KEYCLOAK_URL | sed 's|https://||' | sed 's|http://||')",
  "netbird_auth_authority": "$KEYCLOAK_URL/realms/$NETBIRD_REALM"
}
EOF
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
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   NetBird Keycloak Setup Script       ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    check_dependencies
    validate_inputs
    get_admin_token
    create_realm
    create_netbird_client
    create_management_client
    configure_realm_settings
    generate_secrets
    print_configuration
    
    echo ""
    print_info "Next steps:"
    echo "  1. Update your Ansible vars.yml file with the configuration above"
    echo "  2. Run the Ansible playbook to deploy NetBird"
}

main "$@"
