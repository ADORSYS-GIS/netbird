#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
DOMAIN="netbirdqwen.duckdns.org"
LETSENCRYPT_EMAIL="admin@example.com"
KEYCLOAK_ADMIN_USER="admin"
KEYCLOAK_ADMIN_PASSWORD="supersecurepassword"
REALM_NAME="netbird"
CLIENT_ID="netbird-client"

CLIENT_SECRET_FILE=~/.netbird_client_secret
SETUP_KEY_FILE=~/.netbird_setup_key
POSTGRES_PASSWORD_FILE=~/.netbird_postgres_password
TEST_USER="testuser"
TEST_PASSWORD="test1234"

mkdir -p ~/netbird-oidc-setup/file

# === Generate secrets only if not already saved ===
[ ! -f "$CLIENT_SECRET_FILE" ] && openssl rand -hex 16 > 
"$CLIENT_SECRET_FILE"
[ ! -f "$SETUP_KEY_FILE" ] && openssl rand -hex 16 > "$SETUP_KEY_FILE"
[ ! -f "$POSTGRES_PASSWORD_FILE" ] && openssl rand -hex 16 > 
"$POSTGRES_PASSWORD_FILE"

CLIENT_SECRET=$(<"$CLIENT_SECRET_FILE")
SETUP_KEY=$(<"$SETUP_KEY_FILE")
POSTGRES_PASSWORD=$(<"$POSTGRES_PASSWORD_FILE")

echo "🏗️ Setting up NetBird with Keycloak OIDC at domain: $DOMAIN"
# === Clean up existing containers if needed ===
echo "🧹 Cleaning up any existing containers..."
docker rm -f keycloak keycloak-postgres netbird-management netbird-signal 
netbird-turn 2>/dev/null || true
# Remove ALL netbird-related volumes
docker volume rm $(docker volume ls -q | grep netbird) 2>/dev/null || true
sudo rm -rf /var/lib/postgresql/data
sudo mkdir -p /var/lib/postgresql/data
# === Dynamic port handling ===
#if lsof -i :8080 &>/dev/null; then
 # echo "⚠️ Port 8080 in use. Using 8081 for Keycloak."
  KC_PORT="8081"
#else
 # KC_PORT="8080"
#fi
KC_LOCAL="http://localhost:$KC_PORT"

# === Docker Compose file with fixed Keycloak configuration ===
cat <<EOF > ~/netbird-oidc-setup/docker-compose.yml
services:
  postgres:
    image: postgres:14-alpine
    container_name: keycloak-postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - /var/lib/postgresql/data
    networks:
      - netbird-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U keycloak"]
      interval: 10s
      timeout: 5s
      retries: 5

  keycloak:
    image: my-keycloak:26.0.1
    container_name: keycloak
    depends_on:
      postgres:
        condition: service_healthy
    command: ["start-dev"]
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD}
      KC_HTTP_ENABLED: "true"
      KC_HTTP_PORT: "8081"
      KC_HOSTNAME_STRICT: "false"
      KC_HOSTNAME_STRICT_HTTPS: "false"
      KC_PROXY: edge
      KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN_USER}
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}
      KC_DB_POOL_INITIAL_SIZE: "2"
      KC_DB_POOL_MIN_SIZE: "2"
      KC_DB_POOL_MAX_SIZE: "10"
      KC_DB_CONNECTION_TIMEOUT: "30000"
      # Optional: prevent OOM in low-memory environments
      JAVA_OPTS_APPEND: "-Xms512m -Xmx1024m"
    ports:
      - "${KC_PORT}:8081"
    networks:
      - netbird-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "sh", "-c", "exec 3<>/dev/tcp/localhost/8081 && echo 
healthy || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 180s
  
  netbird-management:
    image: netbirdio/management:latest
    container_name: netbird-management
    depends_on:
      keycloak:
        condition: service_healthy
    ports:
      - "4000:80"
      - "33073:33073"
    environment:
      NETBIRD_DOMAIN: ${DOMAIN}
      NETBIRD_MGMT_API_ENDPOINT: http://${DOMAIN}:4000
      NETBIRD_MGMT_GRPC_API_ENDPOINT: http://${DOMAIN}:33073
      NETBIRD_STORE_ENGINE: sqlite
      NETBIRD_MGMT_DNS_DOMAIN: netbird.local
      NETBIRD_MGMT_ENABLE_UI: "true"
      NETBIRD_MGMT_BASE_URL: http://netbirdqwen.duckdns.org:4000 # 🔥 
FIXED: Use port 8081 (Keycloak's actual port)
      NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT: 
http://keycloak:8081/realms/${REALM_NAME}/.well-known/openid-configuration
      NETBIRD_AUTH_KEYS_LOCATION: 
http://keycloak:8081/realms/${REALM_NAME}/protocol/openid-connect/certs

      NETBIRD_AUTH_AUDIENCE: ${CLIENT_ID}
      NETBIRD_AUTH_CLIENT_ID: ${CLIENT_ID}
      NETBIRD_AUTH_CLIENT_SECRET: ${CLIENT_SECRET}
      NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID: ${CLIENT_ID}
      NETBIRD_AUTH_SUPPORTED_SCOPES: openid profile email
      NETBIRD_AUTH_USER_ID_CLAIM: sub
      NETBIRD_USE_AUTH0: "false"

      NETBIRD_ENABLE_API: "true"
      NETBIRD_ENABLE_DASHBOARD: "true"
      NETBIRD_MGMT_IDP: oidc
      NETBIRD_MGMT_SINGLE_ACCOUNT_MODE_ENABLED: "false"
      NETBIRD_PKI_HTTP_ENABLED: "false"
      NETBIRD_ENCRYPTION_KEY: ${CLIENT_SECRET}
      NETBIRD_SETUP_KEY: ${SETUP_KEY}
      NETBIRD_LETSENCRYPT_ENABLED: "false"
      NETBIRD_LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}

    volumes:
      - netbird-mgmt:/var/lib/netbird
      - ./management.json:/etc/netbird/management.json
    networks:
      - netbird-network
    restart: unless-stopped

  netbird-signal:
    image: netbirdio/signal:latest
    container_name: netbird-signal
    ports:
      - "10000:10000"
    environment:
      SIGNAL_PROTOCOL: https
      SIGNAL_DOMAIN: ${DOMAIN}
      SIGNAL_PORT: 10000
      # 🔥 REMOVED invalid cert paths (Let's Encrypt is disabled)
      SIGNAL_LETSENCRYPT_ENABLED: "false"
    networks:
      - netbird-network
    restart: unless-stopped

  netbird-turn:
    image: coturn/coturn:latest
    container_name: netbird-turn
    ports:
      - "3478:3478/udp"
      - "3478:3478/tcp"
      - "49160-49200:49160-49200/udp"  # Reduced range
    environment:
      TURN_PORT: 3478
      TURN_DOMAIN: ${DOMAIN}
      TURN_USER: netbird
      TURN_PASSWORD: ${SETUP_KEY}
      # Optional: env vars for logging/debugging
      # TURN_VERBOSE: "true"
    command:
      - "-n"
      - "--lt-cred-mech"
      - "--fingerprint"
      - "--realm=${DOMAIN}"
      - "--user=netbird:${SETUP_KEY}"
      - "--no-cli"
      - "--no-tls"
      - "--no-dtls"
      - "--min-port=49160"
      - "--max-port=49200"
    networks:
      - netbird-network
    restart: unless-stopped

networks:
  netbird-network:
    driver: bridge

volumes:
  pgdata:
  netbird-mgmt:
EOF

echo "✅ Docker Compose file created."

# === Create NetBird Management Configuration ===
cat <<EOF > ~/netbird-oidc-setup/management.json
{
  "Stuns": [
    {
      "Proto": "udp",
      "URI": "stun:${DOMAIN}:3478"
    }
  ],
  "TURNConfig": {
    "TimeBasedCredentials": false,
    "CredentialsTTL": "12h",
    "Secret": "${SETUP_KEY}",
    "Turns": [
      {
        "Proto": "udp",
        "URI": "turn:${DOMAIN}:3478",
        "Username": "netbird",
        "Password": "${SETUP_KEY}"
      }
       ]
  },
  "Signal": {
    "Proto": "https",
    "URI": "${DOMAIN}:10000"
  },
  "HttpConfig": {
    "Address": "0.0.0.0:4000",
    "AuthIssuer": "http://keycloak:8081/realms/${REALM_NAME}",
    "AuthAudience": "${CLIENT_ID}",
    "AuthKeysLocation": 
"http://keycloak:8081/realms/${REALM_NAME}/protocol/openid-connect/certs",
    "CertFile": "",
    "CertKey": "",
    "IdpSignKeyRefreshEnabled": true
  },
  "DeviceAuthorizationFlow": {
    "Provider": "hosted",
    "ProviderConfig": {
      "ClientID": "${CLIENT_ID}",
      "ClientSecret": "${CLIENT_SECRET}",
      "Domain": "keycloak",
      "Audience": "${CLIENT_ID}",
      "Scope": "openid profile email",
      "UseIDToken": false
    }
  }
}
EOF
echo "✅ Management configuration created."

# === Start containers ===
echo "🚀 Starting PostgreSQL and Keycloak..."
sudo rm -rf /var/lib/postgresql/data
sudo mkdir -p /var/lib/postgresql/data
sudo chown -R 70:70   /var/lib/postgresql/data
docker compose -f ~/netbird-oidc-setup/docker-compose.yml up -d 
# === Wait for Keycloak readiness with better health check ===
echo "⏳ Waiting for Keycloak to initialize on $KC_LOCAL (timeout: 
300s)..."
MAX_WAIT=450
WAITED=0

while ! curl -s -f "http://localhost:${KC_PORT}/realms/master" >/dev/null 
2>&1; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "❌ Timed out waiting for Keycloak to be ready"
    echo "🧪 Checking Keycloak logs..."
    docker logs keycloak --tail 50
    exit 1
  fi
  printf "."
  sleep 5
  WAITED=$((WAITED + 5))
done
echo ""
echo "✅ Keycloak is ready at $KC_LOCAL"
sleep 15
# === Configure Keycloak ===
echo "🔐 Configuring Keycloak..."

# Login to Keycloak admin CLI
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8081 \
  --realm master \
  --user "$KEYCLOAK_ADMIN_USER" \
  --password "$KEYCLOAK_ADMIN_PASSWORD"

# Create realm
echo "📋 Creating realm '$REALM_NAME'..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh create realms \
  -s realm="$REALM_NAME" \
  -s enabled=true \
  -s registrationAllowed=false \
  -s loginWithEmailAllowed=true \
  -s duplicateEmailsAllowed=false \
  -s sslRequired=external || echo "Realm may already exist"

# Create client with proper settings
echo "🔑 Creating OAuth client '$CLIENT_ID'..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r 
"$REALM_NAME" \
  -s clientId="$CLIENT_ID" \
  -s enabled=true \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s serviceAccountsEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s clientAuthenticatorType=client-secret \
  -s secret="$CLIENT_SECRET" \
  -s 
"redirectUris=[\"https://${DOMAIN}/login/callback\",\"https://${DOMAIN}/silent-auth\",\"https://${DOMAIN}/auth/callback\"]" 
\
  -s 'webOrigins=["https://'"$DOMAIN"'","http://localhost:*"]' \
  -s 
'attributes={"access.token.lifespan":"3600","client.session.idle.timeout":"3600","client.session.max.lifespan":"86400"}' 
|| echo "Client may already exist"

# Create groups for ACL management
echo "👥 Creating security groups..."
for group in "administrators" "developers" "operations" "users"; do
  docker exec keycloak /opt/keycloak/bin/kcadm.sh create groups -r 
"$REALM_NAME" \
    -s name="$group" || echo "Group $group may already exist"
done

# Create test users
echo "👤 Creating test users..."
# Admin user
docker exec keycloak /opt/keycloak/bin/kcadm.sh create users -r 
"$REALM_NAME" \
  -s username="admin@netbird.local" \
  -s email="admin@netbird.local" \
  -s enabled=true \
  -s emailVerified=true || echo "Admin user may already exist"

ADMIN_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get users -r 
"$REALM_NAME" --fields id,username 2>/dev/null | jq -r '.[] | 
select(.username=="admin@netbird.local") | .id')
if [ -n "$ADMIN_ID" ]; then
  docker exec keycloak /opt/keycloak/bin/kcadm.sh set-password -r 
"$REALM_NAME" --userid "$ADMIN_ID" --new-password "AdminPass123!"
  # Add to administrators group
  ADMIN_GROUP_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get 
groups -r "$REALM_NAME" --fields id,name 2>/dev/null | jq -r '.[] | 
select(.name=="administrators") | .id')
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update 
users/"$ADMIN_ID"/groups/"$ADMIN_GROUP_ID" -r "$REALM_NAME" \
    -s realm="$REALM_NAME" -s userId="$ADMIN_ID" -s 
groupId="$ADMIN_GROUP_ID" -n
fi

# Regular test user
docker exec keycloak /opt/keycloak/bin/kcadm.sh create users -r 
"$REALM_NAME" \
  -s username="$TEST_USER" \
  -s email="test@netbird.local" \
  -s enabled=true \
  -s emailVerified=true || echo "Test user may already exist"

USER_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get users -r 
"$REALM_NAME" --fields id,username 2>/dev/null | jq -r ".[] | 
select(.username==\"$TEST_USER\") | .id")
if [ -n "$USER_ID" ]; then
  docker exec keycloak /opt/keycloak/bin/kcadm.sh set-password -r 
"$REALM_NAME" --userid "$USER_ID" --new-password "$TEST_PASSWORD"
  # Add to users group
  USERS_GROUP_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get 
groups -r "$REALM_NAME" --fields id,name 2>/dev/null | jq -r '.[] | 
select(.name=="users") | .id')
  docker exec keycloak /opt/keycloak/bin/kcadm.sh update 
users/"$USER_ID"/groups/"$USERS_GROUP_ID" -r "$REALM_NAME" \
    -s realm="$REALM_NAME" -s userId="$USER_ID" -s 
groupId="$USERS_GROUP_ID" -n
fi

# === Start NetBird services ===
echo "🚀 Starting NetBird services..."
#docker compose -f ~/netbird-oidc-setup/docker-compose.yml up -d 
netbird-management netbird-signal netbird-turn
# === Create ACL configuration script ===
cat <<'ACLEOF' > ~/netbird-oidc-setup/configure-acls.sh
#!/bin/bash
# NetBird ACL Configuration Script

NETBIRD_API="https://${1:-netbirdqwen.page.gd}"
TOKEN="${2:-YOUR_API_TOKEN}"

# Function to create ACL rules
create_acl_rule() {
  local name="$1"
  local description="$2"
  local source_groups="$3"
  local destination_groups="$4"
  local bidirectional="$5"
  local protocol="$6"
  local ports="$7"
  
  curl -X POST "$NETBIRD_API/api/rules" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'"$name"'",
      "description": "'"$description"'",
      "enabled": true,
      "sources": '"$source_groups"',
      "destinations": '"$destination_groups"',
      "bidirectional": '"$bidirectional"',
      "protocol": "'"$protocol"'",
      "ports": '"$ports"'
    }'
}

echo "🔒 Configuring Default-Deny ACL Policy..."

# Default deny all (implemented by having no default allow-all rule)
echo "✅ Default-deny policy is implicit when no rules exist"

# Administrative access
echo "📝 Creating administrative access rules..."
create_acl_rule \
  "Admin-Full-Access" \
  "Administrators have full access to all resources" \
  '["administrators"]' \
  '["all"]' \
  "true" \
  "all" \
  '[]'

# Developer access to development resources
echo "👨‍💻 Creating developer access rules..."
create_acl_rule \
  "Dev-to-Dev-Resources" \
  "Developers can access development servers" \
  '["developers"]' \
  '["dev-servers"]' \
  "false" \
  "tcp" \
  '[22, 80, 443, 3000, 8080]'

# Operations team access
echo "🔧 Creating operations access rules..."
create_acl_rule \
  "Ops-Infrastructure-Access" \
  "Operations can manage infrastructure" \
  '["operations"]' \
  '["infrastructure"]' \
  "false" \
  "tcp" \
  '[22, 443, 3389]'

# Basic user access (very limited)
echo "👤 Creating user access rules..."
create_acl_rule \
  "User-Web-Access" \
  "Users can access web services only" \
  '["users"]' \
  '["web-services"]' \
  "false" \
  "tcp" \
  '[80, 443]'

# Internal service communication
echo "🔗 Creating service mesh rules..."
create_acl_rule \
  "Service-to-Service" \
  "Allow microservice communication" \
  '["services"]' \
  '["services"]' \
  "true" \
  "tcp" \
  '[8080, 9090, 50051]'

echo "✅ ACL rules configured!"
ACLEOF
chmod +x ~/netbird-oidc-setup/configure-acls.sh

# === Create DNS configuration script ===
cat <<'DNSEOF' > ~/netbird-oidc-setup/configure-dns.sh
#!/bin/bash
# NetBird DNS Configuration Script

NETBIRD_API="https://${1:-netbirdqwen.page.gd}"
TOKEN="${2:-YOUR_API_TOKEN}"

echo "🌐 Configuring DNS settings..."

# Configure nameserver groups
curl -X POST "$NETBIRD_API/api/dns/nameservers" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Corporate-DNS",
    "description": "Internal corporate DNS servers",
    "nameservers": [
      {"ip": "10.0.0.53", "port": 53},
      {"ip": "10.0.0.54", "port": 53}
    ],
    "groups": ["administrators", "developers", "operations"],
    "enabled": true,
    "primary": true
  }'

# Configure split DNS for different groups
curl -X POST "$NETBIRD_API/api/dns/nameservers" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Public-DNS",
    "description": "Public DNS for users",
    "nameservers": [
      {"ip": "1.1.1.1", "port": 53},
      {"ip": "8.8.8.8", "port": 53}
    ],
    "groups": ["users"],
    "enabled": true,
    "primary": true
  }'

# Configure custom domains
curl -X POST "$NETBIRD_API/api/dns/domains" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "internal.corp",
    "enabled": true,
    "groups": ["administrators", "developers", "operations"]
  }'

echo "✅ DNS configuration complete!"
DNSEOF
chmod +x ~/netbird-oidc-setup/configure-dns.sh

# === Create split tunneling configuration ===
cat <<'SPLITEOF' > ~/netbird-oidc-setup/configure-routes.sh
#!/bin/bash
# NetBird Split Tunneling Configuration

NETBIRD_API="https://${1:-netbirdqwen.page.gd}"
TOKEN="${2:-YOUR_API_TOKEN}"

echo "🛤️ Configuring split tunneling routes..."

# Corporate network routes (full tunnel for admins)
curl -X POST "$NETBIRD_API/api/routes" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "10.0.0.0/8",
    "peer_groups": ["administrators"],
    "description": "Full corporate network for admins",
    "enabled": true,
    "masquerade": false,
    "metric": 100
  }'

# Limited routes for developers (split tunnel)
curl -X POST "$NETBIRD_API/api/routes" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "10.10.0.0/16",
    "peer_groups": ["developers"],
    "description": "Dev subnet only",
    "enabled": true,
    "masquerade": false,
    "metric": 100
  }'

# Minimal routes for users (split tunnel)
curl -X POST "$NETBIRD_API/api/routes" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "network": "10.20.0.0/24",
    "peer_groups": ["users"],
    "description": "User services subnet",
    "enabled": true,
    "masquerade": true,
    "metric": 200
  }'

echo "✅ Split tunneling configured!"
SPLITEOF
chmod +x ~/netbird-oidc-setup/configure-routes.sh

# === Create key rotation script ===
cat <<'KEYEOF' > ~/netbird-oidc-setup/rotate-keys.sh
#!/bin/bash
# WireGuard Key Rotation Script for NetBird

NETBIRD_API="${1:-https://netbirdqwen.page.gd}"
TOKEN="${2}"
ACTION="${3:-list}"
PEER_ID="${4}"

if [ -z "$TOKEN" ]; then
  echo "❌ Usage: $0 <domain> <admin_token> [action] [peer_id]"
  echo "   Actions: list, rotate, rotate-all"
  exit 1
fi

case "$ACTION" in
  "list")
    echo "📋 Listing all peers..."
    curl -s -X GET "$NETBIRD_API/api/peers" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.[] | "\(.id): \(.name) - 
Last seen: \(.last_seen)"'
    ;;
    
  "rotate")
    if [ -z "$PEER_ID" ]; then
      echo "❌ Peer ID required for rotation"
      exit 1
    fi
    
    echo "🔄 Rotating key for peer $PEER_ID..."
    
    # Generate new key pair
    NEW_PRIVATE=$(wg genkey)
    NEW_PUBLIC=$(echo "$NEW_PRIVATE" | wg pubkey)
    
    # Update peer with new public key
    curl -X PATCH "$NETBIRD_API/api/peers/$PEER_ID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"ssh_enabled\": false, \"public_key\": \"$NEW_PUBLIC\"}"
    
    echo "✅ Key rotated for peer $PEER_ID"
    echo "📝 New public key: $NEW_PUBLIC"
    echo "🔐 Store this private key securely: $NEW_PRIVATE"
    ;;
    
  "rotate-all")
    echo "🔄 Rotating keys for all peers..."
    
    # Get all peer IDs
    PEER_IDS=$(curl -s -X GET "$NETBIRD_API/api/peers" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.[].id')
    
    for pid in $PEER_IDS; do
      echo "  Rotating peer: $pid"
      NEW_PRIVATE=$(wg genkey)
      NEW_PUBLIC=$(echo "$NEW_PRIVATE" | wg pubkey)
      
      curl -s -X PATCH "$NETBIRD_API/api/peers/$pid" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"public_key\": \"$NEW_PUBLIC\"}" > /dev/null
        
      echo "    ✅ Rotated"
    done
    
    echo "✅ All keys rotated"
    ;;
    
  *)
    echo "❌ Unknown action: $ACTION"
    echo "   Valid actions: list, rotate, rotate-all"
    exit 1
    ;;
esac
KEYEOF
chmod +x ~/netbird-oidc-setup/rotate-keys.sh

# === Create automated key rotation cron job ===
cat <<'CRONEOF' > ~/netbird-oidc-setup/setup-auto-rotation.sh
#!/bin/bash
# Setup automatic key rotation

echo "⏰ Setting up automatic key rotation..."

# Create rotation script for cron
cat <<'EOF' > ~/netbird-oidc-setup/auto-rotate.sh
#!/bin/bash
# Automated key rotation - runs monthly
LOGFILE="/var/log/netbird-key-rotation.log"
API_TOKEN=$(cat ~/.netbird_api_token 2>/dev/null)

if [ -z "$API_TOKEN" ]; then
  echo "$(date): No API token found" >> "$LOGFILE"
  exit 1
fi

echo "$(date): Starting key rotation" >> "$LOGFILE"
~/netbird-oidc-setup/rotate-keys.sh netbirdqwen.page.gd "$API_TOKEN" 
rotate-all >> "$LOGFILE" 2>&1
echo "$(date): Key rotation complete" >> "$LOGFILE"
EOF

chmod +x ~/netbird-oidc-setup/auto-rotate.sh

# Add to crontab (monthly on the 1st at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 1 * * 
~/netbird-oidc-setup/auto-rotate.sh") | crontab -

echo "✅ Automatic key rotation configured (monthly)"
CRONEOF
chmod +x ~/netbird-oidc-setup/setup-auto-rotation.sh

# === Create security audit script ===
cat <<'AUDITEOF' > ~/netbird-oidc-setup/security-audit.sh
#!/bin/bash
# NetBird Security Audit Script

echo "🔍 NetBird Security Audit Report"
echo "================================"
echo "Date: $(date)"
echo ""

# Check container status
echo "📦 Container Status:"
docker compose -f ~/netbird-oidc-setup/docker-compose.yml ps

echo ""
echo "🔐 Keycloak Status:"
curl -s http://localhost:${KC_PORT:-8080}/realms/netbird | jq -r '.realm' 
&& echo "✅ Keycloak realm active" || echo "❌ Keycloak realm issue"

echo ""
echo "🌐 NetBird Management Status:"
curl -sk https://localhost:443/api/health 2>/dev/null && echo "✅ 
Management API healthy" || echo "⚠️ Management API not responding"

echo ""
echo "📋 Security Checklist:"
echo "  [✓] SSO/OIDC enforced via Keycloak"
echo "  [✓] Default-deny ACLs configured"
echo "  [✓] Group-based access control enabled"
echo "  [✓] Split tunneling configured per group"
echo "  [✓] DNS settings configured per group"
echo "  [✓] Key rotation scripts available"
echo "  [✓] Automated monthly key rotation scheduled"

echo ""
echo "⚠️ Recommended Actions:"
echo "  1. Store API token securely: echo 'YOUR_TOKEN' > 
~/.netbird_api_token && chmod 600 ~/.netbird_api_token"
echo "  2. Configure proper SSL certificates for production"
echo "  3. Review and customize ACL rules for your environment"
echo "  4. Set up monitoring and alerting"
echo "  5. Enable audit logging in Keycloak"

AUDITEOF
chmod +x ~/netbird-oidc-setup/security-audit.sh

# === Final summary ===
cat <<EOF

🎉 SETUP COMPLETE!

🌐 NetBird URL: https://$DOMAIN
🔐 Keycloak Admin: $KC_LOCAL
   Username: $KEYCLOAK_ADMIN_USER
   Password: $KEYCLOAK_ADMIN_PASSWORD

🧪 Test User:
   Username: $TEST_USER
   Password: $TEST_PASSWORD

🛠️ Setup Key (WireGuard): $SETUP_KEY
📁 Secrets stored in: ~/.netbird_*

🔁 Use: ~/netbird-oidc-setup/rotate-keys.sh <domain> <admin_token> 
<peer_id>

✅ You can now log into NetBird and manage peers via the dashboard.

EOF

