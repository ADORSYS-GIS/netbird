#!/bin/bash

# NetBird Deployment Script
# This script deploys NetBird with Keycloak using Docker Compose

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

log "=== NetBird Deployment ==="

# Check if Docker Compose file exists
if [[ ! -f ~/netbird-deployment/docker-compose.yml ]]; then
    error "Docker Compose file not found. Run 03-create-docker-compose.sh first!"
    exit 1
fi

# Check if environment file exists
if [[ ! -f ~/netbird-deployment/config/netbird.env ]]; then
    error "Environment file not found. Run 02-configure-environment.sh first!"
    exit 1
fi

# Load environment variables and create .env file for Docker Compose
source ~/netbird-deployment/config/netbird.env

# Copy environment file to .env for Docker Compose
log "Preparing environment file for Docker Compose..."
cp ~/netbird-deployment/config/netbird.env ~/netbird-deployment/.env

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    warn "Docker permission issue detected. Trying with sudo..."
    if ! sudo docker info > /dev/null 2>&1; then
        error "Docker is not running or not properly installed."
        error "Try: sudo systemctl start docker"
        exit 1
    else
        warn "Docker works with sudo. You may need to log out/in for group permissions."
        warn "Continuing deployment with sudo..."
        # Create an alias for docker commands in this script
        shopt -s expand_aliases
        alias docker='sudo docker'
        alias docker-compose='sudo docker compose'
    fi
fi

log "Starting NetBird Control Plane deployment..."
info "Domain: $NETBIRD_DOMAIN"
info "Keycloak Admin: admin"

# Change to deployment directory
cd ~/netbird-deployment

# Pull latest images
log "Pulling Docker images..."
docker compose pull

# Start services
log "Starting services..."
docker compose up -d

# Wait for services to start
log "Waiting for services to start..."
sleep 10

# Check service status
log "Checking service status..."
docker compose ps

# Wait for Keycloak to be ready
log "Waiting for Keycloak to be ready..."
for i in {1..30}; do
    # First check localhost (faster)
    if curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
        log "Keycloak is responding on localhost!"
        # Now test external access via domain
        if curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
            log "Keycloak is ready and accessible via domain!"
            break
        else
            warn "Keycloak works on localhost but not via domain. Check DNS/firewall."
            break
        fi
    fi
    info "Waiting for Keycloak... ($i/30)"
    sleep 10
done

# Final accessibility check
if ! curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
    error "Keycloak is not accessible via domain: http://localhost:8080"
    warn "Check logs: docker compose logs keycloak"
    warn "Check DNS: nslookup $NETBIRD_DOMAIN"
    warn "Check firewall: sudo ufw status"
fi

log "=== Deployment Complete! ==="
log ""
log "🎉 NetBird Control Plane is now running!"
log ""
log "📋 Access Information:"
log "  🔐 Keycloak Admin: http://localhost:8080/admin"
log "      Username: admin"
log "      Password: $KEYCLOAK_ADMIN_PASSWORD"
log ""
log "  🌐 NetBird Dashboard: http://localhost:8081"
log "  📡 Management API: https://$NETBIRD_DOMAIN:443"
log ""
log "📁 Important files:"
log "  - Passwords: ~/netbird-deployment/config/IMPORTANT-PASSWORDS.txt"
log "  - Logs: docker compose logs [service-name]"
log ""
log "🔧 Next Steps:"
log "1. Configure Keycloak realm and clients"
log "2. Set up NetBird users and groups"
log "3. Install NetBird clients on devices"
log ""
log "📚 Useful Commands:"
log "  - View logs: docker compose logs -f"
log "  - Stop services: docker compose down"
log "  - Restart services: docker compose restart"
log "  - Update services: docker compose pull && docker compose up -d"

# Create a status check script
cat > ~/netbird-deployment/scripts/check-status.sh << EOF
#!/bin/bash
echo "=== NetBird Service Status ==="
cd ~/netbird-deployment
docker compose ps
echo ""
echo "=== Service Health ==="
echo "Keycloak: \$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/realms/master)"
echo "Dashboard: \$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)"
echo "Management: \$(curl -s -o /dev/null -w "%{http_code}" -k https://$NETBIRD_DOMAIN:443)"
EOF

chmod +x ~/netbird-deployment/scripts/check-status.sh

info "Status check script created: ~/netbird-deployment/scripts/check-status.sh"
