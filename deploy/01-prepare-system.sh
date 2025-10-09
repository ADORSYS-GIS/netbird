#!/bin/bash

# NetBird System Preparation Script
# This script prepares your system with Docker and required tools

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

log "=== NetBird System Preparation ==="
log "This script will:"
log "1. Remove existing Docker installations"
log "2. Install fresh Docker and Docker Compose"
log "3. Install required tools (jq, curl, etc.)"
log "4. Configure firewall for NetBird"
log "5. Create directory structure"
log ""
log "Starting automated system preparation..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "Don't run as root. Run as regular user with sudo privileges."
    exit 1
fi

# Check system requirements
log "Checking system requirements..."
CPU_CORES=$(nproc)
MEMORY_MB=$(free -m | awk 'NR==2{printf "%.0f", $2}')
info "CPU Cores: $CPU_CORES"
info "Memory: ${MEMORY_MB}MB"

if [[ $MEMORY_MB -lt 2048 ]]; then
    warn "Recommended minimum is 2GB RAM. You have ${MEMORY_MB}MB"
fi

# Remove existing Docker
log "Removing existing Docker installations..."
sudo systemctl stop docker.service 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
sudo systemctl stop containerd.service 2>/dev/null || true

DEBIAN_FRONTEND=noninteractive sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

log "Removing Docker data (containers, images, and volumes)..."
sudo rm -rf /var/lib/docker 2>/dev/null || true
sudo rm -rf /var/lib/containerd 2>/dev/null || true
info "Docker data removed"

# Remove docker group if it exists (will be recreated later)
if getent group docker > /dev/null 2>&1; then
    sudo groupdel docker 2>/dev/null || true
    info "Removed existing docker group"
fi

# Install Docker
log "Installing Docker..."
DEBIAN_FRONTEND=noninteractive sudo apt-get update

DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
# Remove existing Docker GPG key if it exists
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

DEBIAN_FRONTEND=noninteractive sudo apt-get update
# Install Docker with non-interactive frontend
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create docker group if it doesn't exist
sudo groupadd docker 2>/dev/null || true

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service with proper error handling
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

# Wait for Docker to be ready
sleep 5

# Verify Docker is running
if ! sudo systemctl is-active --quiet docker; then
    warn "Docker service failed to start, attempting restart..."
    sudo systemctl restart docker
    sleep 5
fi

# Final Docker verification
if sudo systemctl is-active --quiet docker; then
    info "Docker service is running successfully"
    # Test Docker command (as root for now, user will need to log out/in)
    if sudo docker --version > /dev/null 2>&1; then
        info "Docker command is working: $(sudo docker --version)"
    else
        warn "Docker service running but command failed"
    fi
else
    error "Docker service failed to start after multiple attempts"
    error "You may need to manually start Docker: sudo systemctl start docker"
fi

# Install additional tools
log "Installing additional tools..."
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    jq \
    curl \
    wget \
    git \
    unzip \
    htop \
    net-tools \
    ufw

# Configure firewall
log "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow ssh
sudo ufw allow 8081/tcp
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 3478/udp comment 'STUN'
sudo ufw allow 49152:65535/udp comment 'TURN range'
sudo ufw allow 8080/tcp comment 'Keycloak'
sudo ufw allow 10000/tcp comment 'NetBird Signal'

sudo ufw --force enable

# Create directory structure
log "Creating directory structure..."
mkdir -p ~/netbird-deployment/{config,scripts,data,logs}

# Check network
log "Checking network connectivity..."
PUBLIC_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "Unable to detect")
info "Your public IP: $PUBLIC_IP"

# Check ports
info "Checking port availability..."
for port in 80 443 8080; do
    if sudo netstat -tlnp | grep ":$port " > /dev/null; then
        warn "Port $port is already in use"
    else
        info "Port $port is available"
    fi
done

log "=== System Preparation Complete! ==="
warn "IMPORTANT: Log out and log back in for Docker group changes to take effect!"
info "Next step: Run 02-configure-environment.sh"
