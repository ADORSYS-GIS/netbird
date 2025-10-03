#!/bin/bash

# NetBird Docker Compose Configuration Script
# This script creates Docker Compose files for NetBird + Keycloak

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

log "=== Creating Docker Compose Configuration ==="

# Check if environment file exists
if [[ ! -f ~/netbird-deployment/config/netbird.env ]]; then
    error "Environment file not found. Run 02-configure-environment.sh first!"
    exit 1
fi

# Load environment variables
source ~/netbird-deployment/config/netbird.env

log "Creating Docker Compose file..."

cat > ~/netbird-deployment/docker-compose.yml << 'EOF'
services:
  # PostgreSQL Database
  postgres:
    image: postgres:15
    container_name: netbird-postgres
    networks:
      - netbird-network
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_MULTIPLE_DATABASES=netbird,keycloak
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-databases.sh:/docker-entrypoint-initdb.d/init-databases.sh:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Keycloak Identity Provider
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: netbird-keycloak
    networks:
      - netbird-network
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "${KEYCLOAK_HTTP_PORT}:8080"
    environment:
      - KC_DB=${KEYCLOAK_DB_VENDOR}
      - KC_DB_URL=${KEYCLOAK_DB_URL}
      - KC_DB_USERNAME=${KEYCLOAK_DB_USERNAME}
      - KC_DB_PASSWORD=${KEYCLOAK_DB_PASSWORD}
      - KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN}
      - KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
      - KC_HTTP_PORT=8080
      - KC_HOSTNAME_STRICT=false
      - KC_HTTP_ENABLED=true
      - KC_HOSTNAME=${NETBIRD_DOMAIN}
      - KC_HOSTNAME_PORT=${KEYCLOAK_HTTP_PORT}
      - KC_PROXY=edge
      - KC_HOSTNAME_STRICT_HTTPS=false
    command: ["start-dev"]
    volumes:
      - keycloak_data:/opt/keycloak/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "exec 3<>/dev/tcp/localhost/8080"]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 60s

  # NetBird Management Service
  management:
    image: netbirdio/management:latest
    container_name: netbird-management
    networks:
      - netbird-network
    depends_on:
      postgres:
        condition: service_healthy
      keycloak:
        condition: service_healthy
    ports:
      - "${NETBIRD_MGMT_API_PORT}:80"
    environment:
      - NETBIRD_STORE_ENGINE=${NETBIRD_STORE_CONFIG_ENGINE}
      - NETBIRD_STORE_ENGINE_POSTGRES_DSN=${NETBIRD_STORE_ENGINE_POSTGRES_DSN}
      - NETBIRD_IDP_MGMT_CLIENT_ID=${NETBIRD_IDP_MGMT_CLIENT_ID}
      - NETBIRD_IDP_MGMT_CLIENT_SECRET=${NETBIRD_IDP_MGMT_CLIENT_SECRET}
      - NETBIRD_IDP_MGMT_ADMIN_ENDPOINT=${NETBIRD_IDP_MGMT_ADMIN_ENDPOINT}
      - NETBIRD_IDP_MGMT_ENDPOINT=${NETBIRD_IDP_MGMT_ENDPOINT}
      - NETBIRD_IDP_MGMT_EXTRA_ADMIN_ENDPOINT=${NETBIRD_IDP_MGMT_ADMIN_ENDPOINT}
      - NETBIRD_HTTP_API_CORS_ALLOW_ORIGINS=http://192.168.4.123:8081,http://localhost:8081
      - NETBIRD_HTTP_API_CORS_ALLOW_HEADERS=Content-Type,Authorization,Accept
      - NETBIRD_HTTP_API_CORS_ALLOW_METHODS=GET,POST,PUT,DELETE,OPTIONS,PATCH
      - NETBIRD_HTTP_API_CORS_ALLOW_CREDENTIALS=true
    volumes:
      - ./management.json:/etc/netbird/management.json:ro
      - netbird_mgmt:/var/lib/netbird
    restart: unless-stopped
    command: [
      "--port", "80",
      "--log-file", "console",
      "--log-level", "debug",
      "--disable-anonymous-metrics=${NETBIRD_DISABLE_ANONYMOUS_METRICS:-false}",
      "--dns-domain=${NETBIRD_MGMT_DNS_DOMAIN:-netbird.selfhosted}"
    ]

  # NetBird Signal Service
  signal:
    image: netbirdio/signal:latest
    container_name: netbird-signal 
    networks:
      - netbird-network
    ports:
      - "${NETBIRD_SIGNAL_PORT}:80"
    volumes:
      - netbird_signal:/var/lib/netbird
    restart: unless-stopped

  # NetBird Dashboard
  dashboard:
    image: netbirdio/dashboard:latest
    container_name: netbird-dashboard
    networks:
      - netbird-network
    depends_on:
      keycloak:
        condition: service_healthy
      management:
        condition: service_started
    ports:
      - "8081:80"
    environment:
      - NETBIRD_MGMT_API_ENDPOINT=http://${NETBIRD_DOMAIN}:${NETBIRD_MGMT_API_PORT}
      - NETBIRD_MGMT_GRPC_API_ENDPOINT=http://${NETBIRD_DOMAIN}:${NETBIRD_MGMT_API_PORT}
      - AUTH_AUDIENCE=${NETBIRD_AUTH_AUDIENCE}
      - AUTH_CLIENT_ID=${NETBIRD_AUTH_CLIENT_ID}
      - AUTH_CLIENT_SECRET=${NETBIRD_AUTH_CLIENT_SECRET}
      - AUTH_AUTHORITY=${NETBIRD_AUTH_AUTHORITY}
      - AUTH_SUPPORTED_SCOPES=${NETBIRD_AUTH_SUPPORTED_SCOPES}
      - AUTH_SILENT_REDIRECT_URI=http://${NETBIRD_DOMAIN}:8081/
      - NETBIRD_TOKEN_SOURCE=idToken
      - NETBIRD_USE_AUTH0=false
      - USE_AUTH0=false
      # Disable HTTPS for development
      - LETSENCRYPT_DOMAIN=none
      - LETSENCRYPT_EMAIL=none
    volumes:
      - letsencrypt_data:/etc/letsencrypt/
    restart: unless-stopped

  # Coturn STUN/TURN Server
  coturn:
    image: coturn/coturn:latest
    container_name: netbird-coturn
    networks:
      - netbird-network
    ports:
      - "3478:3478/udp"
      - "3478:3478/tcp"
    volumes:
      - ./turnserver.conf:/etc/turnserver.conf:ro
    command: ["-c", "/etc/turnserver.conf"]
    restart: unless-stopped

  # NetBird Relay
  relay:
    image: netbirdio/relay:latest
    container_name: netbird-relay
    networks:
      - netbird-network
    ports:
      - "${NETBIRD_RELAY_PORT}:3479"
    environment:
      - NB_LOG_LEVEL=info
      - NB_LISTEN_ADDRESS=:3479
      - NB_EXPOSED_ADDRESS=${NETBIRD_DOMAIN}:${NETBIRD_RELAY_PORT}
      - NB_AUTH_SECRET=${NETBIRD_RELAY_AUTH_SECRET}
    restart: unless-stopped

networks:
  netbird-network:
    driver: bridge
    name: netbird-network

volumes:
  postgres_data:
  keycloak_data:
  netbird_mgmt:
  netbird_signal:
  letsencrypt_data:
EOF

log "Creating NetBird Management configuration..."

cat > ~/netbird-deployment/management.json << EOF
{
    "Stuns": [
        {
            "Proto": "udp",
            "URI": "stun:localhost:3478",
            "Username": "",
            "Password": null
        }
    ],
    "TURNConfig": {
        "Turns": [
            {
                "Proto": "udp",
                "URI": "turn:localhost:3478",
                "Username": "${TURN_USER}",
                "Password": "${TURN_PASSWORD}"
            }
        ],
        "CredentialsTTL": "12h",
        "Secret": "secret",
        "TimeBasedCredentials": false
    },
    "Relay": {
        "Addresses": ["localhost:${NETBIRD_RELAY_PORT}"],
        "CredentialsTTL": "24h",
        "Secret": "${NETBIRD_RELAY_AUTH_SECRET}"
    },
    "Signal": {
        "Proto": "${NETBIRD_SIGNAL_PROTOCOL}",
        "URI": "localhost:${NETBIRD_SIGNAL_PORT}",
        "Username": "",
        "Password": null
    },
    "HttpConfig": {
        "Address": "0.0.0.0:80",
        "AuthIssuer": "http://keycloak:8080/realms/netbird",
        "AuthAudience": "${NETBIRD_AUTH_AUDIENCE}",
        "AuthKeysLocation": "http://keycloak:8080/realms/netbird/protocol/openid-connect/certs",
        "AuthUserIDClaim": "${NETBIRD_AUTH_USER_ID_CLAIM}",
        "IdpSignKeyRefreshEnabled": ${NETBIRD_MGMT_IDP_SIGNKEY_REFRESH},
        "OIDCConfigEndpoint": "http://keycloak:8080/realms/netbird/.well-known/openid-configuration"
    },
    "IdpManagerConfig": {
        "ManagerType": "${NETBIRD_MGMT_IDP}",
        "ClientConfig": {
            "Issuer": "http://keycloak:8080/realms/netbird",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "ClientID": "${NETBIRD_IDP_MGMT_CLIENT_ID}",
            "ClientSecret": "${NETBIRD_IDP_MGMT_CLIENT_SECRET}",
            "GrantType": "client_credentials"
        },
        "ExtraConfig": {
            "AdminEndpoint": "http://keycloak:8080/admin/realms/netbird"
        }
    },
    "DeviceAuthorizationFlow": {
        "Provider": "${NETBIRD_AUTH_DEVICE_AUTH_PROVIDER}",
        "ProviderConfig": {
            "Audience": "${NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE}",
            "ClientID": "${NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID}",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "DeviceAuthEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/auth/device",
            "Scope": "${NETBIRD_AUTH_DEVICE_AUTH_SCOPE}",
            "UseIDToken": ${NETBIRD_AUTH_DEVICE_AUTH_USE_ID_TOKEN}
        }
    },
    "PKCEAuthorizationFlow": {
        "ProviderConfig": {
            "Audience": "${NETBIRD_AUTH_PKCE_AUDIENCE}",
            "ClientID": "${NETBIRD_AUTH_CLIENT_ID}",
            "ClientSecret": "${NETBIRD_AUTH_CLIENT_SECRET}",
            "AuthorizationEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/auth",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "Scope": "${NETBIRD_AUTH_SUPPORTED_SCOPES}",
            "RedirectURLs": ["${NETBIRD_AUTH_PKCE_REDIRECT_URLS}"],
            "UseIDToken": ${NETBIRD_AUTH_PKCE_USE_ID_TOKEN}
        }
    },
    "StoreConfig": {
        "Engine": "${NETBIRD_STORE_CONFIG_ENGINE}"
    },
    "DataStoreEncryptionKey": "${NETBIRD_DATASTORE_ENC_KEY}"
}
EOF

log "Creating database initialization script..."

cat > ~/netbird-deployment/init-databases.sh << 'EOF'
#!/bin/bash
set -e

# Create multiple databases for NetBird deployment
# This script runs when PostgreSQL container starts for the first time

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create Keycloak database if it doesn't exist
    SELECT 'CREATE DATABASE keycloak'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

    -- Grant privileges to netbird user on keycloak database
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO $POSTGRES_USER;
    
    -- Create extensions if needed
    \c keycloak;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    \c $POSTGRES_DB;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL

echo "Multiple databases created successfully!"
EOF

chmod +x ~/netbird-deployment/init-databases.sh

log "Creating TURN server configuration..."

cat > ~/netbird-deployment/turnserver.conf << EOF
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=0.0.0.0
external-ip=localhost
realm=localhost
server-name=localhost
lt-cred-mech
user=${TURN_USER}:${TURN_PASSWORD}
log-file=stdout
verbose
EOF

# Function to update client secrets after Keycloak configuration
update_client_secrets_post_keycloak() {
    log "🔄 Updating client secrets from Keycloak..."
    
    # Source the update function from environment script
    if [[ -f ~/projects/test/control-plane/netbird/02-configure-environment.sh ]]; then
        source ~/projects/test/control-plane/netbird/02-configure-environment.sh
        update_client_secrets_from_keycloak
    else
        warn "Environment script not found. Client secrets will need manual update."
    fi
    
    # Recreate management.json with updated secrets
    if grep -q "KEYCLOAK_WILL_SET_THIS" ~/netbird-deployment/config/netbird.env; then
        warn "Client secrets not yet retrieved from Keycloak."
        warn "Run the Keycloak configuration script first, then regenerate management.json"
    else
        log "🔄 Regenerating management.json with updated client secrets..."
        # Reload environment with updated secrets
        source ~/netbird-deployment/config/netbird.env
        
        # Recreate management.json (same content as above but with updated variables)
        cat > ~/netbird-deployment/management.json << EOF
{
    "Stuns": [
        {
            "Proto": "udp",
            "URI": "stun:localhost:3478",
            "Username": "",
            "Password": null
        }
    ],
    "TURNConfig": {
        "Turns": [
            {
                "Proto": "udp",
                "URI": "turn:localhost:3478",
                "Username": "${TURN_USER}",
                "Password": "${TURN_PASSWORD}"
            }
        ],
        "CredentialsTTL": "12h",
        "Secret": "secret",
        "TimeBasedCredentials": false
    },
    "Relay": {
        "Addresses": ["localhost:${NETBIRD_RELAY_PORT}"],
        "CredentialsTTL": "24h",
        "Secret": "${NETBIRD_RELAY_AUTH_SECRET}"
    },
    "Signal": {
        "Proto": "${NETBIRD_SIGNAL_PROTOCOL}",
        "URI": "localhost:${NETBIRD_SIGNAL_PORT}",
        "Username": "",
        "Password": null
    },
    "HttpConfig": {
        "Address": "0.0.0.0:80",
        "AuthIssuer": "http://keycloak:8080/realms/netbird",
        "AuthAudience": "${NETBIRD_AUTH_AUDIENCE}",
        "AuthKeysLocation": "http://keycloak:8080/realms/netbird/protocol/openid-connect/certs",
        "AuthUserIDClaim": "${NETBIRD_AUTH_USER_ID_CLAIM}",
        "IdpSignKeyRefreshEnabled": ${NETBIRD_MGMT_IDP_SIGNKEY_REFRESH},
        "OIDCConfigEndpoint": "http://keycloak:8080/realms/netbird/.well-known/openid-configuration"
    },
    "IdpManagerConfig": {
        "ManagerType": "${NETBIRD_MGMT_IDP}",
        "ClientConfig": {
            "Issuer": "http://keycloak:8080/realms/netbird",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "ClientID": "${NETBIRD_IDP_MGMT_CLIENT_ID}",
            "ClientSecret": "${NETBIRD_IDP_MGMT_CLIENT_SECRET}",
            "GrantType": "client_credentials"
        },
        "AdminEndpoint": "http://keycloak:8080/admin/realms/netbird"
    },
    "DeviceAuthorizationFlow": {
        "Provider": "${NETBIRD_AUTH_DEVICE_AUTH_PROVIDER}",
        "ProviderConfig": {
            "Audience": "${NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE}",
            "ClientID": "${NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID}",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "DeviceAuthEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/auth/device",
            "Scope": "${NETBIRD_AUTH_DEVICE_AUTH_SCOPE}",
            "UseIDToken": ${NETBIRD_AUTH_DEVICE_AUTH_USE_ID_TOKEN}
        }
    },
    "PKCEAuthorizationFlow": {
        "ProviderConfig": {
            "Audience": "${NETBIRD_AUTH_PKCE_AUDIENCE}",
            "ClientID": "${NETBIRD_AUTH_CLIENT_ID}",
            "ClientSecret": "${NETBIRD_AUTH_CLIENT_SECRET}",
            "AuthorizationEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/auth",
            "TokenEndpoint": "http://keycloak:8080/realms/netbird/protocol/openid-connect/token",
            "Scope": "${NETBIRD_AUTH_SUPPORTED_SCOPES}",
            "RedirectURLs": ["${NETBIRD_AUTH_PKCE_REDIRECT_URLS}"],
            "UseIDToken": ${NETBIRD_AUTH_PKCE_USE_ID_TOKEN}
        }
    },
    "StoreConfig": {
        "Engine": "${NETBIRD_STORE_CONFIG_ENGINE}"
    },
    "DataStoreEncryptionKey": "${NETBIRD_DATASTORE_ENC_KEY}"
}
EOF
        log "✅ Management.json updated with Keycloak client secrets"
    fi
}

log "=== Docker Compose Configuration Complete! ==="
info "Files created:"
info "  - ~/netbird-deployment/docker-compose.yml"
info "  - ~/netbird-deployment/management.json"
info "  - ~/netbird-deployment/turnserver.conf"
info ""
info "📝 Note: After running Keycloak configuration, you can call:"
info "   update_client_secrets_post_keycloak"
info "   to update all configuration files with Keycloak client secrets"
info ""
info "Next step: Run 04-deploy-netbird.sh"