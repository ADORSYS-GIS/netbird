#!/bin/bash

# NetBird Environment Configuration Script
# This script creates configuration files for NetBird with Keycloak

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

log "=== NetBird Environment Configuration ==="
log "This script creates configuration files for:"
log "1. NetBird environment variables"
log "2. Keycloak settings"
log "3. Docker Compose configuration"

# Check if directory exists
if [[ ! -d ~/netbird-deployment ]]; then
    log "ERROR: Directory ~/netbird-deployment not found. Run 01-prepare-system.sh first!"
    exit 1
fi

# Check if environment file already exists and preserve existing passwords
if [[ -f ~/netbird-deployment/config/netbird.env ]]; then
    log "Existing environment file found. Preserving existing passwords..."
    source ~/netbird-deployment/config/netbird.env
    EXISTING_KEYCLOAK_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD
    EXISTING_POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    EXISTING_RELAY_SECRET=$NETBIRD_RELAY_AUTH_SECRET
    EXISTING_TURN_PASSWORD=$TURN_PASSWORD
    EXISTING_DATASTORE_KEY=$NETBIRD_DATASTORE_ENC_KEY
    EXISTING_MGMT_SECRET=$NETBIRD_IDP_MGMT_CLIENT_SECRET
else
    log "Creating new environment with fresh passwords..."
    EXISTING_KEYCLOAK_PASSWORD=""
    EXISTING_POSTGRES_PASSWORD=""
    EXISTING_RELAY_SECRET=""
    EXISTING_TURN_PASSWORD=""
    EXISTING_DATASTORE_KEY=""
    EXISTING_MGMT_SECRET=""
fi

# Generate secure passwords (using hex to avoid special characters)
# Use existing passwords if available, otherwise generate new ones
KEYCLOAK_ADMIN_PASSWORD=${EXISTING_KEYCLOAK_PASSWORD:-$(openssl rand -hex 16)}
POSTGRES_PASSWORD=${EXISTING_POSTGRES_PASSWORD:-$(openssl rand -hex 16)}
RELAY_AUTH_SECRET=${EXISTING_RELAY_SECRET:-$(openssl rand -base64 32)}
TURN_PASSWORD=${EXISTING_TURN_PASSWORD:-$(openssl rand -base64 16)}
DATASTORE_ENC_KEY=${EXISTING_DATASTORE_KEY:-$(openssl rand -base64 32)}
KEYCLOAK_MGMT_SECRET=${EXISTING_MGMT_SECRET:-$(openssl rand -base64 32)}

# Function to sync passwords with running containers
sync_with_running_containers() {
    log "🔄 Checking for running containers and syncing passwords..."
    
    # Check if Keycloak container is running
    if docker ps --format "table {{.Names}}" | grep -q "netbird-keycloak"; then
        log "Found running Keycloak container. Syncing password..."
        CONTAINER_KEYCLOAK_PASSWORD=$(cd ~/netbird-deployment && docker compose exec keycloak env | grep KEYCLOAK_ADMIN_PASSWORD | cut -d'=' -f2)
        if [[ -n "$CONTAINER_KEYCLOAK_PASSWORD" && "$CONTAINER_KEYCLOAK_PASSWORD" != "$KEYCLOAK_ADMIN_PASSWORD" ]]; then
            warn "Container password differs from config. Using container password."
            KEYCLOAK_ADMIN_PASSWORD=$CONTAINER_KEYCLOAK_PASSWORD
        fi
    fi
    
    # Check if PostgreSQL container is running
    if docker ps --format "table {{.Names}}" | grep -q "netbird-postgres"; then
        log "Found running PostgreSQL container. Password sync not needed (uses env file)."
    fi
}

# Sync with running containers if they exist
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    sync_with_running_containers
fi

log "Creating environment configuration..."

ENV_FILE=~/netbird-deployment/config/netbird.env

cat > "$ENV_FILE" << EOF
# NetBird Control Plane Configuration with Keycloak
# Your Domain and Network Settings
# IMPORTANT: Change 'localhost' to your machine's public IP or a real domain name.
# Using 'localhost' works for the browser but causes issues for internal services
# like the Management API because it is a different network context.
# We will use the container name for inter-service communication where possible.
NETBIRD_DOMAIN=192.168.4.123
NETBIRD_LETSENCRYPT_DOMAIN=192.168.4.123
NETBIRD_LETSENCRYPT_EMAIL=admin@192.168.4.123
# Your Public IP: 143.105.152.187
# Domain resolves to: 143.105.152.187 ✓

# Database Configuration (using PostgreSQL for production)
NETBIRD_STORE_CONFIG_ENGINE=postgres
POSTGRES_DB=netbird
POSTGRES_USER=netbird
POSTGRES_PASSWORD=PLACEHOLDER_POSTGRES_PASSWORD
NETBIRD_STORE_ENGINE_POSTGRES_DSN=postgres://netbird:PLACEHOLDER_POSTGRES_PASSWORD@postgres:5432/netbird?sslmode=disable

# Keycloak Identity Provider Configuration
NETBIRD_MGMT_IDP=keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=PLACEHOLDER_KEYCLOAK_ADMIN_PASSWORD
KEYCLOAK_DB_VENDOR=postgres
KEYCLOAK_DB_URL=jdbc:postgresql://postgres:5432/keycloak
KEYCLOAK_DB_USERNAME=netbird
KEYCLOAK_DB_PASSWORD=PLACEHOLDER_POSTGRES_PASSWORD
KEYCLOAK_HTTP_PORT=8080

# The Keycloak hostname that the user's browser will see.
# This must match what is in the issued token's iss claim.
# The keycloak service name is only for internal container communication.
# This variable is used by the Keycloak container itself.

NETBIRD_AUTH_AUTHORITY=http://${NETBIRD_DOMAIN}:8080/realms/netbird

# These URLs are used by the NetBird Management API to validate tokens.
# Since the Management API is in a different container, it MUST use the
# service name 'keycloak' to communicate with Keycloak.
NETBIRD_AUTH_CLIENT_ID=netbird-client
NETBIRD_AUTH_CLIENT_SECRET=gzMJ9Ep45NSHcDStvaHGQOTMAuqErHX8
NETBIRD_AUTH_JWT_CERTS=http://keycloak:8080/realms/netbird/protocol/openid-connect/certs
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=http://keycloak:8080/realms/netbird/.well-known/openid-configuration
NETBIRD_AUTH_TOKEN_ENDPOINT=http://keycloak:8080/realms/netbird/protocol/openid-connect/token
NETBIRD_AUTH_USER_ID_CLAIM=sub
NETBIRD_AUTH_AUDIENCE=netbird-client
NETBIRD_DASH_AUTH_AUDIENCE=netbird-client

# NetBird Management API
NETBIRD_MGMT_API_PORT=8082
NETBIRD_MGMT_SINGLE_ACCOUNT_MODE_DOMAIN=localhost
NETBIRD_MGMT_IDP_SIGNKEY_REFRESH=true

# NetBird Signal Server
NETBIRD_SIGNAL_PORT=10000
NETBIRD_SIGNAL_PROTOCOL=http

# NetBird Relay Server
NETBIRD_RELAY_PORT=3479
NETBIRD_RELAY_AUTH_SECRET=PLACEHOLDER_RELAY_SECRET

# TURN Server Configuration
TURN_DOMAIN=localhost
TURN_USER=netbird
TURN_PASSWORD=PLACEHOLDER_TURN_PASSWORD

# Security
NETBIRD_DATASTORE_ENC_KEY=PLACEHOLDER_DATASTORE_KEY

# Device Authorization Flow (for CLI clients)
NETBIRD_AUTH_DEVICE_AUTH_PROVIDER=keycloak
NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID=netbird-device
NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE=netbird-client
NETBIRD_AUTH_DEVICE_AUTH_ENDPOINT=http://keycloak:8080/realms/netbird/protocol/openid-connect/auth/device
NETBIRD_AUTH_DEVICE_AUTH_SCOPE="openid profile email"
NETBIRD_AUTH_DEVICE_AUTH_USE_ID_TOKEN=false

# PKCE Authorization Flow (Fixed URLs)
NETBIRD_AUTH_PKCE_AUDIENCE=account
NETBIRD_AUTH_PKCE_AUTHORIZATION_ENDPOINT=http://${NETBIRD_DOMAIN}:8080/realms/netbird/protocol/openid-connect/auth
NETBIRD_AUTH_PKCE_REDIRECT_URLS=http://${NETBIRD_DOMAIN}:8081/
NETBIRD_AUTH_PKCE_USE_ID_TOKEN=false
NETBIRD_AUTH_PKCE_DISABLE_PROMPT_LOGIN=false
NETBIRD_AUTH_PKCE_LOGIN_FLAG=false
NETBIRD_AUTH_SUPPORTED_SCOPES="openid profile email"

# Management Client Configuration
NETBIRD_IDP_MGMT_CLIENT_ID=netbird-management
NETBIRD_IDP_MGMT_CLIENT_SECRET=1AT5C5WkHYhHnbt4i84lxUUJpVcCryT2Pn/FaiaVFk4=
# IDP Manager Configuration
NETBIRD_IDP_MGMT_ENDPOINT=http://keycloak:8080/realms/netbird
NETBIRD_IDP_MGMT_ADMIN_ENDPOINT=http://keycloak:8080/admin/realms/netbird

# Optional Settings
NETBIRD_DISABLE_ANONYMOUS_METRICS=false
EOF


# URL encode the PostgreSQL password for the connection string
POSTGRES_PASSWORD_ENCODED=$(echo "$POSTGRES_PASSWORD" | sed 's|/|%2F|g; s|=|%3D|g; s|+|%2B|g')

# Replace placeholders with actual values (using | delimiter to avoid issues with special chars)
sed -i "s|PLACEHOLDER_DOMAIN|$NETBIRD_DOMAIN|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_PUBLIC_IP|$PUBLIC_IP|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_POSTGRES_PASSWORD|$POSTGRES_PASSWORD|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_KEYCLOAK_ADMIN_PASSWORD|$KEYCLOAK_ADMIN_PASSWORD|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_RELAY_SECRET|$RELAY_AUTH_SECRET|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_TURN_PASSWORD|$TURN_PASSWORD|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_DATASTORE_KEY|$DATASTORE_ENC_KEY|g" "$ENV_FILE"
sed -i "s|PLACEHOLDER_MGMT_CLIENT_SECRET|$KEYCLOAK_MGMT_SECRET|g" "$ENV_FILE"

# Fix the PostgreSQL DSN with URL-encoded password
sed -i "s|postgres://netbird:$POSTGRES_PASSWORD@|postgres://netbird:$POSTGRES_PASSWORD_ENCODED@|g" "$ENV_FILE"

log "Environment configuration created!"

# Create a summary file
cat > ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt << EOF
NetBird + Keycloak Important Information
=======================================

Domain: usher-netbird.duckdns.org
Public IP: 143.105.152.187

KEYCLOAK ACCESS:
- Admin URL: http://localhost:8080/admin
- Username: admin
- Password: $KEYCLOAK_ADMIN_PASSWORD

NETBIRD ACCESS:
- Dashboard: http://localhost:8081
- Management API: http://localhost:8082

DATABASE ACCESS:
- PostgreSQL Database: netbird
- PostgreSQL User: netbird
- PostgreSQL Password: $POSTGRES_PASSWORD

GENERATED SECRETS:
- Keycloak Admin Password: $KEYCLOAK_ADMIN_PASSWORD
- PostgreSQL Password: $POSTGRES_PASSWORD
- Relay Auth Secret: $RELAY_AUTH_SECRET
- TURN Password: $TURN_PASSWORD
- Datastore Encryption Key: $DATASTORE_ENC_KEY
- Keycloak Management Secret: $KEYCLOAK_MGMT_SECRET

NOTE: Client secrets will be retrieved from Keycloak after client creation

IMPORTANT: Keep this file secure and backup these passwords!
EOF

chmod 600 ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt

# Function to update client secrets from Keycloak (called after Keycloak is running)
update_client_secrets_from_keycloak() {
    log "🔄 Updating client secrets from Keycloak..."
    
    # Check if Keycloak is accessible
    if ! curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
        warn "Keycloak not accessible yet. Client secrets will be updated later."
        return 0
    fi
    
    # Change to deployment directory
    cd ~/netbird-deployment
    
    # Configure Keycloak Admin CLI
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user admin \
        --password "$KEYCLOAK_ADMIN_PASSWORD" 2>/dev/null; then
        
        # Get NetBird web client secret
        WEB_CLIENT_UUID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            --target-realm netbird \
            --query clientId=netbird-client \
            --fields id 2>/dev/null | jq -r '.[0].id')
        
        if [[ -n "$WEB_CLIENT_UUID" && "$WEB_CLIENT_UUID" != "null" ]]; then
            WEB_CLIENT_SECRET=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$WEB_CLIENT_UUID/client-secret \
                --target-realm netbird 2>/dev/null | jq -r '.value')
            
            if [[ -n "$WEB_CLIENT_SECRET" && "$WEB_CLIENT_SECRET" != "null" ]]; then
                # Update environment file
                sed -i "s|KEYCLOAK_WILL_SET_THIS|$WEB_CLIENT_SECRET|g" ~/netbird-deployment/config/netbird.env
                log "✅ Client secret updated from Keycloak: ${WEB_CLIENT_SECRET:0:8}..."
                
                # Update password file
                echo "" >> ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt
                echo "KEYCLOAK CLIENT SECRETS (Retrieved):" >> ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt
                echo "- NetBird Web Client Secret: $WEB_CLIENT_SECRET" >> ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt
            fi
        fi
    fi
}

log "=== Environment Configuration Complete! ==="
info "Configuration files created:"
info "  - ~/netbird-deployment/config/netbird.env"
info "  - ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt"
warn "IMPORTANT: Backup the IMPORTANT-PASSWORDS.txt file!"
info ""
info "📝 Note: Client secrets will be automatically retrieved from Keycloak"
info "   after the services are deployed and configured."
info ""
info "Next step: Run 03-create-docker-compose.sh"
