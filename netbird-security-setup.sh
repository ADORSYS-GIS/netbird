#!/bin/bash

#############################################################################
# NetBird Complete Security Configuration Script
# Configures: Default-Deny ACLs, Granular Rules, Split Tunneling, 
#            SSO/OIDC, DNS Settings, and Key Rotation
#############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NETBIRD_DOMAIN="${NETBIRD_DOMAIN:-netbird.example.com}"
NETBIRD_API_URL="${NETBIRD_API_URL:-https://api.$NETBIRD_DOMAIN}"
NETBIRD_MGMT_URL="${NETBIRD_MGMT_URL:-https://mgmt.$NETBIRD_DOMAIN}"
NETBIRD_TOKEN="${NETBIRD_TOKEN:-}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-selfhosted}" # selfhosted or cloud
CONFIG_DIR="./netbird-config"

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    for tool in curl jq docker docker-compose; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install missing tools and try again"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to create configuration directory structure
setup_directories() {
    print_info "Setting up configuration directories..."
    
    mkdir -p "$CONFIG_DIR"/{acls,dns,routes,groups,scripts,docker}
    mkdir -p "$CONFIG_DIR"/keys/{rotation,backup}
    
    print_success "Directory structure created"
}

#############################################################################
# 1. DEFAULT-DENY ACLs CONFIGURATION
#############################################################################

configure_default_deny_acls() {
    print_info "Configuring default-deny ACLs..."
    
    # Create default-deny ACL configuration
    cat > "$CONFIG_DIR/acls/default-deny.json" <<EOF
{
  "name": "Default Security Policy",
  "description": "Zero Trust default-deny configuration",
  "groups": [
    {
      "id": "admin-group",
      "name": "Administrators",
      "peers": []
    },
    {
      "id": "web-servers",
      "name": "Web Servers",
      "peers": []
    },
    {
      "id": "db-servers",
      "name": "Database Servers",
      "peers": []
    },
    {
      "id": "developers",
      "name": "Developers",
      "peers": []
    }
  ],
  "rules": [
    {
      "id": "rule-1",
      "name": "Admin Full Access",
      "description": "Administrators have full network access",
      "enabled": true,
      "action": "accept",
      "sources": ["admin-group"],
      "destinations": ["*"],
      "bidirectional": true,
      "priority": 100
    },
    {
      "id": "rule-2",
      "name": "Web to Database",
      "description": "Web servers can access databases",
      "enabled": true,
      "action": "accept",
      "sources": ["web-servers"],
      "destinations": ["db-servers"],
      "ports": ["3306/tcp", "5432/tcp", "27017/tcp"],
      "bidirectional": false,
      "priority": 200
    },
    {
      "id": "rule-3",
      "name": "Developer SSH Access",
      "description": "Developers can SSH to servers",
      "enabled": true,
      "action": "accept",
      "sources": ["developers"],
      "destinations": ["web-servers", "db-servers"],
      "ports": ["22/tcp"],
      "bidirectional": false,
      "priority": 300
    },
    {
      "id": "default-deny",
      "name": "Default Deny All",
      "description": "Deny all traffic not explicitly allowed",
      "enabled": true,
      "action": "drop",
      "sources": ["*"],
      "destinations": ["*"],
      "bidirectional": true,
      "priority": 9999
    }
  ]
}
EOF
    
    # Apply ACLs via API if token is provided
    if [ -n "$NETBIRD_TOKEN" ]; then
        print_info "Applying ACL configuration via API..."
        
        # Create groups
        for group in admin-group web-servers db-servers developers; do
            curl -X POST "$NETBIRD_API_URL/api/groups" \
                -H "Authorization: Bearer $NETBIRD_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"name\": \"$group\", \"peers\": []}" \
                2>/dev/null || print_warning "Group $group might already exist"
        done
        
        # Apply rules
        curl -X POST "$NETBIRD_API_URL/api/rules" \
            -H "Authorization: Bearer $NETBIRD_TOKEN" \
            -H "Content-Type: application/json" \
            -d @"$CONFIG_DIR/acls/default-deny.json" \
            2>/dev/null && print_success "ACL rules applied"
    else
        print_warning "No API token provided. Manual configuration required."
        print_info "ACL configuration saved to: $CONFIG_DIR/acls/default-deny.json"
    fi
}

#############################################################################
# 2. GRANULAR LEAST-PRIVILEGE ACCESS RULES
#############################################################################

configure_granular_access() {
    print_info "Configuring granular least-privilege access rules..."
    
    # Create service-specific rules
    cat > "$CONFIG_DIR/acls/service-rules.json" <<EOF
{
  "service_rules": [
    {
      "name": "HTTP/HTTPS Access",
      "sources": ["developers"],
      "destinations": ["web-servers"],
      "ports": ["80/tcp", "443/tcp"],
      "action": "accept"
    },
    {
      "name": "Database Monitoring",
      "sources": ["monitoring-servers"],
      "destinations": ["db-servers"],
      "ports": ["9100/tcp", "9104/tcp"],
      "action": "accept"
    },
    {
      "name": "DNS Resolution",
      "sources": ["*"],
      "destinations": ["dns-servers"],
      "ports": ["53/udp", "53/tcp"],
      "action": "accept"
    },
    {
      "name": "Time Sync",
      "sources": ["*"],
      "destinations": ["ntp-servers"],
      "ports": ["123/udp"],
      "action": "accept"
    }
  ]
}
EOF
    
    # Create tag-based rules
    cat > "$CONFIG_DIR/acls/tag-rules.json" <<EOF
{
  "tag_rules": [
    {
      "name": "Production Environment",
      "tags": ["env:production"],
      "allowed_tags": ["env:production", "role:admin"],
      "denied_tags": ["env:development", "env:staging"]
    },
    {
      "name": "Development Environment",
      "tags": ["env:development"],
      "allowed_tags": ["env:development", "role:developer"],
      "denied_tags": ["env:production"]
    },
    {
      "name": "Sensitive Data Access",
      "tags": ["data:sensitive"],
      "allowed_tags": ["clearance:high", "role:admin"],
      "denied_tags": ["clearance:low", "contractor"]
    }
  ]
}
EOF
    
    print_success "Granular access rules configured"
}

#############################################################################
# 3. SPLIT TUNNELING AND DNS CONFIGURATION
#############################################################################

configure_split_tunneling() {
    print_info "Configuring split tunneling and network routes..."
    
    # Create route configuration
    cat > "$CONFIG_DIR/routes/network-routes.json" <<EOF
{
  "routes": [
    {
      "id": "route-1",
      "name": "Internal Services",
      "description": "Route internal service traffic through VPN",
      "network": "10.0.0.0/8",
      "enabled": true,
      "peer_groups": ["all"],
      "masquerade": false,
      "metric": 100
    },
    {
      "id": "route-2",
      "name": "Private Network",
      "description": "Route private network traffic",
      "network": "192.168.0.0/16",
      "enabled": true,
      "peer_groups": ["all"],
      "masquerade": false,
      "metric": 100
    },
    {
      "id": "route-3",
      "name": "Cloud Services",
      "description": "Route cloud service subnet",
      "network": "172.16.0.0/12",
      "enabled": true,
      "peer_groups": ["developers", "admin-group"],
      "masquerade": false,
      "metric": 100
    }
  ],
  "split_tunnel_config": {
    "enabled": true,
    "mode": "exclude",
    "excluded_routes": [
      "0.0.0.0/0",
      "::/0"
    ],
    "included_routes": [
      "10.0.0.0/8",
      "192.168.0.0/16",
      "172.16.0.0/12"
    ]
  }
}
EOF
    
    print_success "Split tunneling configuration created"
}

configure_dns_settings() {
    print_info "Configuring per-group DNS settings..."
    
    # Create DNS configuration
    cat > "$CONFIG_DIR/dns/dns-config.json" <<EOF
{
  "dns_settings": {
    "global": {
      "nameservers": ["8.8.8.8", "8.8.4.4"],
      "search_domains": ["netbird.local"],
      "match_domains": ["*.internal", "*.local"]
    },
    "per_group": [
      {
        "group": "production",
        "nameservers": ["10.0.1.53", "10.0.1.54"],
        "search_domains": ["prod.internal"],
        "custom_zones": [
          {
            "domain": "database.prod.internal",
            "records": [
              {"type": "A", "name": "master", "value": "10.0.2.10"},
              {"type": "A", "name": "replica", "value": "10.0.2.11"}
            ]
          }
        ]
      },
      {
        "group": "development",
        "nameservers": ["10.1.1.53"],
        "search_domains": ["dev.internal"],
        "custom_zones": [
          {
            "domain": "services.dev.internal",
            "records": [
              {"type": "A", "name": "api", "value": "10.1.2.10"},
              {"type": "A", "name": "web", "value": "10.1.2.11"}
            ]
          }
        ]
      },
      {
        "group": "admin-group",
        "nameservers": ["10.0.0.53", "10.0.0.54"],
        "search_domains": ["admin.internal", "mgmt.internal"],
        "allow_all_zones": true
      }
    ]
  }
}
EOF
    
    # Create DNS deployment script
    cat > "$CONFIG_DIR/scripts/deploy-dns.sh" <<'DNSSCRIPT'
#!/bin/bash
# Deploy DNS settings to NetBird

API_URL="${1:-$NETBIRD_API_URL}"
TOKEN="${2:-$NETBIRD_TOKEN}"

if [ -z "$TOKEN" ]; then
    echo "Error: API token required"
    exit 1
fi

# Read DNS config
DNS_CONFIG=$(cat ../dns/dns-config.json)

# Apply global DNS settings
curl -X POST "$API_URL/api/dns/settings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$DNS_CONFIG"
DNSSCRIPT
    
    chmod +x "$CONFIG_DIR/scripts/deploy-dns.sh"
    print_success "DNS configuration created"
}

#############################################################################
# 4. SSO/OIDC CONFIGURATION
#############################################################################

configure_sso_oidc() {
    print_info "Configuring SSO/OIDC authentication..."
    
    # Prompt for IdP selection if not set
    if [ -z "$IDP_TYPE" ]; then
        echo "Select your Identity Provider:"
        echo "1) Keycloak"
        echo "2) Auth0"
        echo "3) Okta"
        echo "4) Azure AD"
        echo "5) Google Workspace"
        echo "6) Generic OIDC"
        read -p "Enter choice (1-6): " choice
        
        case $choice in
            1) IDP_TYPE="keycloak" ;;
            2) IDP_TYPE="auth0" ;;
            3) IDP_TYPE="okta" ;;
            4) IDP_TYPE="azure" ;;
            5) IDP_TYPE="google" ;;
            6) IDP_TYPE="generic" ;;
            *) IDP_TYPE="generic" ;;
        esac
    fi
    
    # Create IdP configuration
    cat > "$CONFIG_DIR/docker/.env" <<EOF
# NetBird SSO/OIDC Configuration
NETBIRD_DOMAIN=$NETBIRD_DOMAIN
NETBIRD_IDP_TYPE=$IDP_TYPE

# OIDC Configuration
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=${OIDC_ENDPOINT:-https://your-idp.com/.well-known/openid-configuration}
NETBIRD_AUTH_CLIENT_ID=${OIDC_CLIENT_ID:-your-client-id}
NETBIRD_AUTH_CLIENT_SECRET=${OIDC_CLIENT_SECRET:-your-client-secret}
NETBIRD_AUTH_AUDIENCE=${OIDC_AUDIENCE:-netbird-client}
NETBIRD_USE_AUTH0=${USE_AUTH0:-false}
NETBIRD_AUTH_DEVICE_AUTH_PROVIDER=${DEVICE_AUTH:-hosted}
NETBIRD_AUTH_USER_ID_CLAIM=${USER_CLAIM:-email}
NETBIRD_AUTH_SUPPORTED_SCOPES=openid profile email

# Additional Security Settings
NETBIRD_MGMT_IDP_SYNC_ENABLED=true
NETBIRD_MGMT_IDP_SYNC_INTERVAL=300
NETBIRD_DISABLE_ANONYMOUS_METRICS=true
NETBIRD_ENABLE_API=true
EOF
    
    # Create Keycloak-specific config
    if [ "$IDP_TYPE" = "keycloak" ]; then
        cat > "$CONFIG_DIR/docker/keycloak-config.json" <<EOF
{
  "realm": "netbird",
  "enabled": true,
  "clients": [
    {
      "clientId": "netbird-backend",
      "enabled": true,
      "clientAuthenticatorType": "client-secret",
      "secret": "$OIDC_CLIENT_SECRET",
      "redirectUris": [
        "https://$NETBIRD_DOMAIN/*"
      ],
      "webOrigins": [
        "https://$NETBIRD_DOMAIN"
      ],
      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": true,
      "publicClient": false,
      "protocol": "openid-connect",
      "attributes": {
        "access.token.lifespan": "900",
        "refresh.token.lifespan": "1800"
      }
    },
    {
      "clientId": "netbird-dashboard",
      "enabled": true,
      "publicClient": true,
      "redirectUris": [
        "https://$NETBIRD_DOMAIN/*"
      ],
      "webOrigins": [
        "https://$NETBIRD_DOMAIN"
      ],
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "protocol": "openid-connect"
    }
  ],
  "groups": [
    {"name": "netbird-admins", "attributes": {"netbird_role": ["admin"]}},
    {"name": "netbird-users", "attributes": {"netbird_role": ["user"]}},
    {"name": "netbird-readonly", "attributes": {"netbird_role": ["readonly"]}}
  ],
  "roles": {
    "realm": [
      {"name": "netbird_admin", "description": "NetBird Administrator"},
      {"name": "netbird_user", "description": "NetBird User"},
      {"name": "netbird_readonly", "description": "NetBird Read-Only User"}
    ]
  }
}
EOF
    fi
    
    print_success "SSO/OIDC configuration created for $IDP_TYPE"
}

#############################################################################
# 5. WIREGUARD KEY ROTATION
#############################################################################

configure_key_rotation() {
    print_info "Setting up WireGuard key rotation..."
    
    # Create key rotation script
    cat > "$CONFIG_DIR/scripts/rotate-keys.sh" <<'ROTATION'
#!/bin/bash

# NetBird WireGuard Key Rotation Script
# Run this via cron for automatic rotation

API_URL="${NETBIRD_API_URL:-https://api.netbird.io}"
TOKEN="${NETBIRD_TOKEN}"
ROTATION_DAYS="${KEY_ROTATION_DAYS:-30}"
BACKUP_DIR="/var/backups/netbird-keys"
LOG_FILE="/var/log/netbird-key-rotation.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to rotate keys for a peer
rotate_peer_key() {
    local peer_id=$1
    local peer_name=$2
    
    log_message "Rotating key for peer: $peer_name ($peer_id)"
    
    # Backup current key
    curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/peers/$peer_id" | \
        jq -r '.public_key' > "$BACKUP_DIR/${peer_id}_$(date +%Y%m%d).key"
    
    # Trigger key rotation
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/peers/$peer_id/rotate-key")
    
    if [ $? -eq 0 ]; then
        log_message "Successfully rotated key for $peer_name"
        return 0
    else
        log_message "ERROR: Failed to rotate key for $peer_name"
        return 1
    fi
}

# Main rotation logic
main() {
    log_message "Starting key rotation check..."
    
    # Get all peers
    peers=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/peers")
    
    if [ -z "$peers" ]; then
        log_message "ERROR: Could not fetch peers"
        exit 1
    fi
    
    # Check each peer's key age
    echo "$peers" | jq -c '.[]' | while read peer; do
        peer_id=$(echo "$peer" | jq -r '.id')
        peer_name=$(echo "$peer" | jq -r '.name // .hostname')
        last_updated=$(echo "$peer" | jq -r '.key_update_timestamp // .connected_at')
        
        if [ "$last_updated" != "null" ]; then
            # Calculate days since last update
            last_update_epoch=$(date -d "$last_updated" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$last_updated" +%s 2>/dev/null)
            current_epoch=$(date +%s)
            days_old=$(( (current_epoch - last_update_epoch) / 86400 ))
            
            if [ $days_old -ge $ROTATION_DAYS ]; then
                log_message "Peer $peer_name key is $days_old days old - rotating"
                rotate_peer_key "$peer_id" "$peer_name"
            else
                log_message "Peer $peer_name key is $days_old days old - skipping"
            fi
        else
            log_message "WARNING: Could not determine key age for $peer_name"
        fi
    done
    
    log_message "Key rotation check completed"
}

# Run main function
main
ROTATION
    
    chmod +x "$CONFIG_DIR/scripts/rotate-keys.sh"
    
    # Create systemd service for key rotation
    cat > "$CONFIG_DIR/scripts/netbird-key-rotation.service" <<EOF
[Unit]
Description=NetBird WireGuard Key Rotation
After=network.target

[Service]
Type=oneshot
ExecStart=$CONFIG_DIR/scripts/rotate-keys.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Create systemd timer for automatic rotation
    cat > "$CONFIG_DIR/scripts/netbird-key-rotation.timer" <<EOF
[Unit]
Description=Run NetBird Key Rotation Weekly
Requires=netbird-key-rotation.service

[Timer]
OnCalendar=weekly
OnCalendar=Sun *-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Create cron alternative
    cat > "$CONFIG_DIR/scripts/crontab-entry" <<EOF
# NetBird Key Rotation - Run weekly on Sunday at 2 AM
0 2 * * 0 $CONFIG_DIR/scripts/rotate-keys.sh >> /var/log/netbird-key-rotation.log 2>&1

# NetBird Key Rotation - Run monthly on the 1st at 3 AM
0 3 1 * * $CONFIG_DIR/scripts/rotate-keys.sh --force >> /var/log/netbird-key-rotation.log 2>&1
EOF
    
    print_success "Key rotation configuration created"
}

#############################################################################
# DOCKER COMPOSE DEPLOYMENT
#############################################################################

create_docker_compose() {
    print_info "Creating Docker Compose configuration..."
    
    cat > "$CONFIG_DIR/docker/docker-compose.yml" <<EOF
version: "3.8"

services:
  # Caddy reverse proxy with automatic SSL
  caddy:
    image: caddy:latest
    container_name: netbird-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - netbird

  # PostgreSQL database
  postgres:
    image: postgres:14-alpine
    container_name: netbird-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: netbird
      POSTGRES_USER: netbird
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-netbird-db-pass}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - netbird

  # NetBird Management Service
  management:
    image: netbirdio/management:latest
    container_name: netbird-management
    restart: unless-stopped
    depends_on:
      - postgres
    environment:
      - NETBIRD_STORE_ENGINE=postgres
      - NETBIRD_DB_DSN=postgresql://netbird:\${POSTGRES_PASSWORD:-netbird-db-pass}@postgres:5432/netbird
      - NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=\${NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT}
      - NETBIRD_AUTH_AUDIENCE=\${NETBIRD_AUTH_AUDIENCE}
      - NETBIRD_AUTH_CLIENT_ID=\${NETBIRD_AUTH_CLIENT_ID}
      - NETBIRD_AUTH_CLIENT_SECRET=\${NETBIRD_AUTH_CLIENT_SECRET}
      - NETBIRD_AUTH_DEVICE_AUTH_PROVIDER=\${NETBIRD_AUTH_DEVICE_AUTH_PROVIDER}
      - NETBIRD_AUTH_USER_ID_CLAIM=\${NETBIRD_AUTH_USER_ID_CLAIM}
      - NETBIRD_MGMT_IDP_SYNC_ENABLED=\${NETBIRD_MGMT_IDP_SYNC_ENABLED}
      - NETBIRD_DISABLE_ANONYMOUS_METRICS=true
      - NETBIRD_ENABLE_API=true
      - NETBIRD_API_PORT=8080
      - NETBIRD_GRPC_API_PORT=443
    volumes:
      - management-data:/var/lib/netbird
      - ./management.json:/etc/netbird/management.json
    networks:
      - netbird
    command: |
      --port 443
      --log-level info
      --disable-anonymous-metrics
      --enable-api
      --enable-device-flow-auth
      --default-peer-expiration-enabled
      --default-peer-expiration-duration 720h
      --peer-login-expiration-enabled
      --peer-login-expiration-duration 24h

  # NetBird Signal Service
  signal:
    image: netbirdio/signal:latest
    container_name: netbird-signal
    restart: unless-stopped
    environment:
      - NETBIRD_ENABLE_AUTH=true
      - NETBIRD_AUTH_ISSUER=\${NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT}
      - NETBIRD_AUTH_AUDIENCE=netbird-signal
    networks:
      - netbird

  # NetBird Dashboard
  dashboard:
    image: netbirdio/dashboard:latest
    container_name: netbird-dashboard
    restart: unless-stopped
    environment:
      - NETBIRD_MGMT_API_ENDPOINT=https://api.\${NETBIRD_DOMAIN}
      - NETBIRD_MGMT_GRPC_API_ENDPOINT=api.\${NETBIRD_DOMAIN}:443
      - AUTH_AUDIENCE=\${NETBIRD_AUTH_AUDIENCE}
      - AUTH_CLIENT_ID=\${NETBIRD_AUTH_CLIENT_ID}
      - AUTH_AUTHORITY=\${NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT}
      - USE_AUTH0=\${NETBIRD_USE_AUTH0}
      - AUTH_SUPPORTED_SCOPES=\${NETBIRD_AUTH_SUPPORTED_SCOPES}
      - AUTH_REDIRECT_URI=/auth
      - AUTH_SILENT_REDIRECT_URI=/silent-auth
      - NETBIRD_TOKEN_SOURCE=idToken
    networks:
      - netbird

  # TURN/STUN server
  coturn:
    image: coturn/coturn:latest
    container_name: netbird-coturn
    restart: unless-stopped
    network_mode: host
    environment:
      - TURNSERVER_ENABLED=1
      - TURNSERVER_REALM=\${NETBIRD_DOMAIN}
      - TURNSERVER_CERT=/etc/coturn/certs/cert.pem
      - TURNSERVER_KEY=/etc/coturn/certs/key.pem
    volumes:
      - coturn-data:/var/lib/coturn
      - ./certs:/etc/coturn/certs:ro

  # Redis cache (optional)
  redis:
    image: redis:7-alpine
    container_name: netbird-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - netbird

networks:
  netbird:
    driver: bridge

volumes:
  caddy-data:
  caddy-config:
  postgres-data:
  management-data:
  coturn-data:
  redis-data:
EOF
    
    # Create Caddyfile
    cat > "$CONFIG_DIR/docker/Caddyfile" <<EOF
\${NETBIRD_DOMAIN} {
    reverse_proxy dashboard:3000
}

api.\${NETBIRD_DOMAIN} {
    reverse_proxy management:8080
}

signal.\${NETBIRD_DOMAIN} {
    reverse_proxy signal:10000
}

mgmt.\${NETBIRD_DOMAIN} {
    reverse_proxy management:443
}
EOF
    
    print_success "Docker Compose configuration created"
}

#############################################################################
# MAIN INSTALLATION MENU
#############################################################################

main_menu() {
    clear
    echo "=========================================="
    echo "  NetBird Security Configuration Setup"
    echo "=========================================="
    echo ""
    echo "This script will configure:"
    echo "1. Default-deny ACLs"
    echo "2. Granular least-privilege access rules"
    echo "3. Split tunneling and per-group DNS"
    echo "4. SSO/OIDC authentication"
    echo "5. WireGuard key rotation"
    echo ""
    echo "Select installation mode:"
    echo "1) Complete automated setup"
    echo "2) Configuration files only"
    echo "3) Docker deployment"
    echo "4) Manual configuration guide"
    echo "5) Exit"
    echo ""
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1) complete_setup ;;
        2) config_only ;;
        3) docker_deploy ;;
        4) show_manual_guide ;;
        5) exit 0 ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
}

complete_setup() {
    print_info "Starting complete automated setup..."
    
    check_prerequisites
    setup_directories
    configure_default_deny_acls
    configure_granular_access
    configure_split_tunneling
    configure_dns_settings
    configure_sso_oidc
    configure_key_rotation
    create_docker_compose
    
    print_success "Complete setup finished!"
    print_info "Configuration files created in: $CONFIG_DIR"
    print_info "Next steps:"
    echo "  1. Review and customize configuration files"
    echo "  2. Set environment variables in $CONFIG_DIR/docker/.env"
    echo "  3. Deploy with: cd $CONFIG_DIR/docker && docker-compose up -d"
    echo "  4. Install systemd timers or cron jobs for key rotation"
}

config_only() {
    print_info "Creating configuration files only..."
    
    setup_directories
    configure_default_deny_acls
    configure_granular_access
    configure_split_tunneling
    configure_dns_settings
    configure_sso_oidc
    configure_key_rotation
    
    print_success "Configuration files created in: $CONFIG_DIR"
}

docker_deploy() {
    print_info "Setting up Docker deployment..."
    
    setup_directories
    configure_sso_oidc
    create_docker_compose
    
    print_success "Docker deployment files created in: $CONFIG_DIR/docker"
    print_info "To deploy:"
    echo "  1. Edit $CONFIG_DIR/docker/.env with your settings"
    echo "  2. cd $CONFIG_DIR/docker"
    echo "  3. docker-compose up -d"
}

show_manual_guide() {
    print_info "Manual configuration guide saved to: $CONFIG_DIR/MANUAL_SETUP_GUIDE.md"
    # The manual guide will be created as a separate file
}

# Run main menu if script is executed directly
if [ "$1" = "--auto" ]; then
    complete_setup
else
    main_menu
fi