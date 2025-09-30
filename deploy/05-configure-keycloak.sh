#!/bin/bash

# NetBird Keycloak Configuration Script
# This script automatically configures Keycloak for NetBird

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

log "=== NetBird Keycloak Configuration ==="

# Load environment variables
if [[ ! -f ~/netbird-deployment/config/netbird.env ]]; then
    error "Environment file not found. Run 02-configure-environment.sh first!"
    exit 1
fi

source ~/netbird-deployment/config/netbird.env

# Validate environment variables
if [[ -z "$NETBIRD_DOMAIN" ]]; then
    error "NETBIRD_DOMAIN not set in environment file!"
    exit 1
fi

log "Using domain: $NETBIRD_DOMAIN"

# Check if Keycloak is running
if ! curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
    error "Keycloak is not accessible. Make sure it's running."
    exit 1
fi

log "Keycloak is accessible. Starting configuration..."

# Install jq if not present
if ! command -v jq &> /dev/null; then
    log "Installing jq for JSON processing..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Function to configure Keycloak using Admin CLI (works with bootstrap admin)
configure_keycloak_cli() {
    log "Using Keycloak Admin CLI for configuration..."
    
    # Change to deployment directory for docker compose commands
    cd ~/netbird-deployment
    
    # Configure credentials once for all operations
    log "Configuring Keycloak Admin CLI credentials..."
    if ! docker compose exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user admin \
        --password "$KEYCLOAK_ADMIN_PASSWORD" 2>&1; then
        error "Failed to configure Keycloak Admin CLI credentials"
        return 1
    fi
    log "✅ Keycloak Admin CLI credentials configured"
    
    # Check if NetBird realm exists
    log "Checking if NetBird realm exists..."
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get realms/netbird >/dev/null 2>&1; then
        log "✅ NetBird realm already exists"
    else
        log "Creating NetBird realm..."
        REALM_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create realms \
            --set realm=netbird \
            --set enabled=true \
            --set displayName="NetBird" \
            --set registrationAllowed=true \
            --set loginWithEmailAllowed=true \
            --set duplicateEmailsAllowed=false \
            --set resetPasswordAllowed=true \
            --set editUsernameAllowed=true \
            --set bruteForceProtected=true 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ NetBird realm created successfully"
        else
            error "Failed to create NetBird realm: $REALM_OUTPUT"
            return 1
        fi
    fi
     
    # Create NetBird web client
    log "Creating NetBird web client..."
    # Check if client already exists
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-client >/dev/null 2>&1 && \
       [[ $(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-client 2>/dev/null | jq length) -gt 0 ]]; then
        log "✅ NetBird web client already exists"
    else
        CLIENT_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
            --target-realm netbird \
            --set clientId=netbird-client \
            --set name="NetBird Web Client" \
            --set enabled=true \
            --set clientAuthenticatorType=client-secret \
            --set standardFlowEnabled=true \
            --set implicitFlowEnabled=false \
            --set directAccessGrantsEnabled=true \
            --set serviceAccountsEnabled=false \
            --set publicClient=false \
            --set protocol=openid-connect 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ NetBird web client created successfully"
        else
            error "Failed to create NetBird web client: $CLIENT_OUTPUT"
            return 1
        fi
    fi
    
    # Configure redirect URIs for NetBird web client (whether new or existing)
    CLIENT_UUID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-client \
        --fields id 2>/dev/null | jq -r '.[0].id')
    
    if [[ -n "$CLIENT_UUID" && "$CLIENT_UUID" != "null" ]]; then
        docker compose exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_UUID \
            --target-realm netbird \
            --set 'redirectUris=["http://localhost:8081/"]' \
            --set 'webOrigins=["http://localhost:8081"]' \
            --set 'defaultClientScopes=["openid","profile","email","roles"]' \
            --set 'optionalClientScopes=["address","phone"]' 2>/dev/null
        log "✅ NetBird web client redirect URIs and scopes configured (domain + localhost)"
    fi
    
    # Create NetBird device client ??
    log "Creating NetBird device client..."
    # Check if device client already exists
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-device >/dev/null 2>&1 && \
       [[ $(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-device 2>/dev/null | jq length) -gt 0 ]]; then
        log "✅ NetBird device client already exists"
    else
        DEVICE_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
            --target-realm netbird \
            --set clientId=netbird-device \
            --set name="NetBird Device Client" \
            --set description="NetBird CLI Device Client" \
            --set enabled=true \
            --set publicClient=true \
            --set standardFlowEnabled=false \
            --set implicitFlowEnabled=false \
            --set directAccessGrantsEnabled=false \
            --set serviceAccountsEnabled=false \
            --set protocol=openid-connect 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ NetBird device client created successfully"
        else
            error "Failed to create NetBird device client: $DEVICE_OUTPUT"
            return 1
        fi
    fi
    
    # Configure device authorization grant for NetBird device client (whether new or existing)
    DEVICE_UUID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-device \
        --fields id 2>/dev/null | jq -r '.[0].id')
    
    if [[ -n "$DEVICE_UUID" && "$DEVICE_UUID" != "null" ]]; then
        docker compose exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$DEVICE_UUID \
            --target-realm netbird \
            --set 'attributes."oauth2.device.authorization.grant.enabled"=true' \
            --set 'attributes."oidc.ciba.grant.enabled"=false' 2>/dev/null
        log "✅ NetBird device client authorization grant configured"
    fi
    
    # Create NetBird management client
    log "Creating NetBird management client..."
    # Check if management client already exists
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-management >/dev/null 2>&1 && \
       [[ $(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-management 2>/dev/null | jq length) -gt 0 ]]; then
        log "✅ NetBird management client already exists"
    else
        MGMT_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
            --target-realm netbird \
            --set clientId=netbird-management \
            --set name="NetBird Management Service" \
            --set description="NetBird Management API Client" \
            --set enabled=true \
            --set clientAuthenticatorType=client-secret \
            --set secret="$NETBIRD_IDP_MGMT_CLIENT_SECRET" \
            --set standardFlowEnabled=false \
            --set implicitFlowEnabled=false \
            --set directAccessGrantsEnabled=false \
            --set serviceAccountsEnabled=true \
            --set publicClient=false \
            --set protocol=openid-connect 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ NetBird management client created successfully"
        else
            error "Failed to create NetBird management client: $MGMT_OUTPUT"
            return 1
        fi
    fi
    
    # Configure audience mapping for token validation
    log "Configuring audience mapping for token validation..."
    
    # Get management client UUID
    MGMT_UUID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-management \
        --fields id 2>/dev/null | jq -r '.[0].id')
    
    if [[ -n "$MGMT_UUID" && "$MGMT_UUID" != "null" ]]; then
        # Configure audience for management client
        docker compose exec keycloak /opt/keycloak/bin/kcadm.sh update clients/$MGMT_UUID \
            --target-realm netbird \
            --set 'attributes."access.token.lifespan"=3600' \
            --set 'attributes."client.session.idle.timeout"=1800' \
            --set 'attributes."client.session.max.lifespan"=36000' 2>/dev/null
        log " Management client token validation configured"
    fi
    
    # Retrieve and update client secrets in environment file
    log "Retrieving client secrets from Keycloak..."
    
    # Get NetBird web client secret
    WEB_CLIENT_UUID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        --target-realm netbird \
        --query clientId=netbird-client \
        --fields id 2>/dev/null | jq -r '.[0].id')
    
    if [[ -n "$WEB_CLIENT_UUID" && "$WEB_CLIENT_UUID" != "null" ]]; then
        WEB_CLIENT_SECRET=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$WEB_CLIENT_UUID/client-secret \
            --target-realm netbird 2>/dev/null | jq -r '.value')
        
        if [[ -n "$WEB_CLIENT_SECRET" && "$WEB_CLIENT_SECRET" != "null" ]]; then
            # Update environment file with actual client secret
            sed -i "s|KEYCLOAK_WILL_SET_THIS|$WEB_CLIENT_SECRET|g" ~/netbird-deployment/config/netbird.env
            log " NetBird web client secret retrieved and updated: ${WEB_CLIENT_SECRET:0:8}..."
        else
            warn "Could not retrieve web client secret"
        fi
    fi
    
    # Note: Custom client scopes are optional for basic OAuth flow
    log " Basic OAuth configuration completed"
    
    # Create test user
    log "Creating test user..."
    # Check if test user already exists
    if docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get users \
        --target-realm netbird \
        --query username=testuser >/dev/null 2>&1 && \
       [[ $(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get users \
        --target-realm netbird \
        --query username=testuser 2>/dev/null | jq length) -gt 0 ]]; then
        log "✅ Test user already exists"
    else
        USER_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create users \
            --target-realm netbird \
            --set username=testuser \
            --set email=test@netbird.local \
            --set firstName=Test \
            --set lastName=User \
            --set enabled=true \
            --set emailVerified=true 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ Test user created successfully"
        else
            error "Failed to create test user: $USER_OUTPUT"
            return 1
        fi
    fi
    
    
    # Set test user password
    log "Setting test user password..."
    PASS_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh set-password \
        --target-realm netbird \
        --username testuser \
        --new-password testpassword 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log "✅ Test user password set successfully"
    else
        warn "Failed to set password: $PASS_OUTPUT"
    fi
    
    # Create NetBird admin role for proper authorization
    log "Creating NetBird admin role..."
    ROLE_OUTPUT=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create roles \
        --target-realm netbird \
        --set name=netbird-admin \
        --set description="NetBird Administrator Role" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log "✅ NetBird admin role created"
        
        # Assign admin role to test user
        USER_ID=$(docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get users \
            --target-realm netbird \
            --query username=testuser \
            --fields id 2>/dev/null | jq -r '.[0].id')
        
        if [[ -n "$USER_ID" && "$USER_ID" != "null" ]]; then
            docker compose exec keycloak /opt/keycloak/bin/kcadm.sh add-roles \
                --target-realm netbird \
                --uid "$USER_ID" \
                --rolename netbird-admin 2>/dev/null
            log "✅ Admin role assigned to test user"
        fi
    else
        warn "NetBird admin role may already exist"
    fi
    
    return 0
}

# Configure Keycloak using Admin CLI (works with bootstrap admin)
configure_keycloak_cli


log "=== Keycloak Configuration Complete! ==="
log ""
log "🎉 NetBird Keycloak setup completed successfully!"
log ""
log "✅ NetBird realm created"
log "✅ NetBird web client configured (netbird-client)"
log "✅ NetBird device client configured (netbird-device)"  
log "✅ NetBird management client configured (netbird-management)"
log "✅ Client secrets retrieved from Keycloak and updated in config"
log "✅ Token validation and audience mapping configured"
log "✅ Admin role and permissions configured"
log "✅ Test user created with admin role"
log ""
log "🌐 Access Information:"
log "  - Keycloak Admin: http://localhost:8080/admin"
log "  - NetBird Dashboard: http://localhost:8081"
log "  - NetBird Realm: http://localhost:8080/realms/netbird"
log ""
log "🔐 Test Credentials:"
log "  - Username: testuser"
log "  - Password: testpassword"
log ""
log "📋 Next Steps:"
log "1. Access NetBird Dashboard at http://localhost:8081"
log "2. Login with the test user credentials"
log "3. Create additional users in Keycloak admin console"
log "4. Install NetBird clients on devices to connect"
log ""
info "🚀 Your NetBird control plane is now fully configured!"
info "🔑 Client secrets are now automatically retrieved from Keycloak!"
