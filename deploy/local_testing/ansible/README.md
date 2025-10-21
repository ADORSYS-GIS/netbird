# NetBird Control Plane - Automated Deployment Guide

## 📖 What is This?

This Ansible playbook **automatically deploys a complete NetBird Control Plane** with:
- **NetBird Management API** - Controls peer connections and network policies
- **NetBird Dashboard** - Web UI for managing your NetBird network  
- **Keycloak** - Identity provider for user authentication (SSO)
- **PostgreSQL** - Database for NetBird and Keycloak data
- **Signal Server** - Coordinates peer-to-peer connections
- **Relay Server** - Fallback when direct P2P fails
- **TURN/STUN** - NAT traversal for connecting peers behind firewalls

### ✅ What Gets Automated

- ✅ Docker and Docker Compose installation
- ✅ Firewall configuration (UFW)
- ✅ Secure password generation (32-character secrets)
- ✅ Keycloak realm and client creation
- ✅ OAuth 2.0 Device Authorization Flow setup (for CLI peers)
- ✅ Client secret synchronization between Keycloak and NetBird
- ✅ Network configuration (internal Docker vs external access)
- ✅ All critical security fixes applied automatically


## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Dashboard     │    │   Management    │    │   Keycloak      │
│   Port: 8081    │    │   Port: 8082    │    │   Port: 8080    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌─────────────────┬─────┴─────┬─────────────────┐
         │                 │           │                 │
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   PostgreSQL    │ │     Signal      │ │     Relay       │ │   TURN/STUN     │
│   (Internal)    │ │   Port: 10000   │ │   Port: 3479    │ │   Port: 3478    │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## 📌 Prerequisites

### Server Requirements

**Target Server** (where NetBird will run):
- Ubuntu 20.04+ or Debian 11+
- Minimum 2GB RAM (4GB recommended)
- 2+ CPU cores
- 10GB+ free disk space
- **Static IP address** or reliable DHCP reservation
- Internet access to download Docker images

**Control Machine** (where you run Ansible from):
- Ansible 2.9 or higher
- SSH access to target server
- SSH key-based authentication (recommended)

### Required Ports

These ports will be opened on the server firewall:
- `8080` - Keycloak (Identity Provider)
- `8081` - NetBird Dashboard (Web UI)
- `8082` - NetBird Management API  
- `10000` - Signal Server (Peer coordination)
- `3478` - TURN/STUN (NAT traversal - TCP & UDP)
- `3479` - Relay Server (Fallback connections)

---

## 🚀 Step-by-Step Deployment

### Step 1: Install Ansible (on your control machine)

```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install ansible

# Verify installation
ansible --version
# Should show: ansible 2.9+
```

### Step 2: Navigate to Ansible Directory

```bash
# Navigate to the playbook directory
cd /path/to/netbird/deploy/ansible

# Verify files are present
ls -la
# You should see: inventory/, roles/, templates/, deploy-complete.yml
```

### Step 3: Configure Your Server Details

Edit `inventory/hosts.yml` with your server information:

```yaml
---
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: YOUR_SERVER_IP    # ← YOUR SERVER IP
          ansible_user: yourusername      # ← YOUR SSH USERNAME
          netbird_role: primary
      vars:
        netbird_external_domain: "YOUR_SERVER_IP"  # ← IP or domain for external access
        netbird_base_dir: "/home/yourusername/netbird-deployment"
```

**Important**: Replace:
- `YOUR_SERVER_IP` with your actual server IP address
- `yourusername` with your SSH username on the server

### Step 4: Test SSH Connection

```bash
# Test Ansible can reach your server
ansible -i inventory/hosts.yml netbird -m ping

# Expected output:
# netbird-primary | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

**If this fails:**
```bash
# Test SSH manually first
ssh yourusername@YOUR_SERVER_IP

# If using password authentication instead of SSH keys
ansible -i inventory/hosts.yml netbird -m ping --ask-pass
```

### Step 5: Run the Deployment

```bash
# Deploy everything (takes 10-15 minutes)
ansible-playbook -i inventory/hosts.yml deploy-complete.yml

# With verbose output (for debugging)
ansible-playbook -i inventory/hosts.yml deploy-complete.yml -v
```

**What happens during deployment:**

1. **System Preparation** (≪2 min)
   - Removes old Docker installations
   - Installs Docker and Docker Compose
   - Adds your user to docker group
   - Configures UFW firewall
   - Opens required ports

2. **Environment Configuration** (~1 min)
   - Generates secure 32-character passwords
   - Creates encryption keys (AES-256)
   - Generates client secrets
   - Creates environment files (.env)

3. **Docker Deployment** (~3-5 min)
   - Creates docker-compose.yml
   - Pulls NetBird, Keycloak, PostgreSQL images
   - Starts all containers
   - Waits for health checks

4. **Keycloak Configuration** (~2-3 min)
   - Creates "netbird" realm
   - Creates 3 clients: netbird-client, netbird-device, netbird-management
   - Enables OAuth 2.0 Device Authorization Flow
   - Adds audience mappers for token validation
   - Synchronizes client secrets

5. **Verification** (~1 min)
   - Checks all services are running
   - Validates Keycloak realm
   - Tests management API

**Total time**: 10-15 minutes depending on your internet speed.

---

## ✅ Post-Deployment: Verify Everything Works

### Step 1: Check All Services Are Running

SSH into your server and check Docker containers:

```bash
ssh yourusername@YOUR_SERVER_IP
cd ~/netbird-deployment
sudo docker compose ps
```

**Expected output** (all should show "Up" or "Up (healthy)"):
```
NAME                 STATUS          PORTS
netbird-postgres     Up (healthy)    5432/tcp
netbird-keycloak     Up (healthy)    0.0.0.0:8080->8080/tcp
netbird-management   Up              0.0.0.0:8082->80/tcp
netbird-dashboard    Up              0.0.0.0:8081->80/tcp
netbird-signal       Up              0.0.0.0:10000->80/tcp
netbird-relay        Up              0.0.0.0:3479->3479/tcp
netbird-coturn       Up              0.0.0.0:3478->3478/tcp,udp
```

### Step 2: Find Your Credentials

All generated passwords are saved in:

```bash
cat ~/netbird-deployment/config/PASSWORDS-GENERATED.txt
```

This file contains:
- Keycloak admin password
- PostgreSQL password  
- All generated secrets and keys

**Important**: Save this file securely!

### Step 3: Access the Web Interfaces

**NetBird Dashboard**:
```
http://YOUR_SERVER_IP:8081
Example: http://YOUR_SERVER_IP:8081
```

**Keycloak Admin Console**:
```
http://YOUR_SERVER_IP:8080/admin
Example: http://YOUR_SERVER_IP:8080/admin

Realm: master
Username: admin
Password: (from PASSWORDS-GENERATED.txt)
```

### Step 4: Test Dashboard Login

1. Open `http://YOUR_SERVER_IP:8081` in your browser
2. Click "Login" button
3. You'll be redirected to Keycloak login page
4. Login with admin credentials (from PASSWORDS-GENERATED.txt)
5. You should see the NetBird dashboard

---

## 👥 Adding Peers (Clients) to Your Network

### What is a Peer?

A "peer" is any device (laptop, server, phone) that connects to your NetBird network. Once connected, peers can communicate with each other securely through NetBird's mesh network.

### Step 1: Install NetBird Client

On the machine you want to add as a peer:

```bash
# Ubuntu/Debian
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Verify installation
netbird version
```

### Step 2: Connect Peer to Control Plane

```bash
# Replace YOUR_SERVER_IP with your NetBird server IP
netbird up --management-url http://YOUR_SERVER_IP:8082

# Example:
netbird up --management-url http://YOUR_SERVER_IP:8082
```

**What happens next:**

1. The command will display an SSO login URL:
```
Please do the SSO login in your browser.
If your browser didn't open automatically, use this URL:

http://YOUR_SERVER_IP:8080/realms/netbird/device?user_code=ABCD-EFGH
```

2. **Open the URL in your web browser**
3. **Login with your Keycloak credentials**
4. After successful login, return to terminal
5. The peer will automatically register and connect
6. You'll see: `Connected to NetBird`

### Step 3: Verify Peer is Connected

**On the peer machine:**
```bash
# Check connection status
netbird status

# Expected output:
# Daemon status: Connected
# Management: Connected
# Signal: Connected
# Peers count: X

# View detailed status
netbird status --detail
```

**In the Dashboard:**
1. Go to `http://YOUR_SERVER_IP:8081`
2. Click on "Peers" in the sidebar
3. Your new peer should appear with status "Online" ✅
4. You can see the peer's IP, name, and connection status

### Troubleshooting Peer Connection

**Issue**: "context deadline exceeded" error

**Cause**: Peer cannot reach the Management API (network issue)

**Solutions**:
```bash
# Test connectivity from peer machine
ping YOUR_SERVER_IP
telnet YOUR_SERVER_IP 8082
curl http://YOUR_SERVER_IP:8082/api/peers

# If peer and server are on different networks:
# - Check firewall rules
# - Ensure port 8082 is accessible
# - May need port forwarding or VPN

# Restart NetBird daemon
sudo systemctl restart netbird
```

---

## 🔧 Maintenance & Operations

### View Service Logs

On your server:

```bash
cd ~/netbird-deployment

# View all service logs
sudo docker compose logs -f

# View specific service logs
sudo docker compose logs -f management
sudo docker compose logs -f keycloak
sudo docker compose logs -f dashboard

# View last 50 lines
sudo docker compose logs --tail 50 management

# Search logs for errors
sudo docker compose logs management | grep -i error
```

### Restart Services

```bash
cd ~/netbird-deployment

# Restart all services
sudo docker compose restart

# Restart specific service
sudo docker compose restart management
sudo docker compose restart keycloak

# Stop and start (full restart)
sudo docker compose down
sudo docker compose up -d
```

### Update NetBird to Latest Version

```bash
cd ~/netbird-deployment

# Pull latest images
sudo docker compose pull

# Restart with new images
sudo docker compose up -d

# Check versions
sudo docker compose images
```

### Backup Important Data

```bash
# Backup environment and configuration
cp -r ~/netbird-deployment/config ~/netbird-backup-$(date +%Y%m%d)
cp ~/netbird-deployment/.env ~/netbird-backup-$(date +%Y%m%d)/
cp ~/netbird-deployment/management.json ~/netbird-backup-$(date +%Y%m%d)/

# Backup PostgreSQL database
cd ~/netbird-deployment
sudo docker compose exec -T postgres pg_dump -U netbird netbird > netbird-db-backup-$(date +%Y%m%d).sql

# Restore database (if needed)
sudo docker compose exec -T postgres psql -U netbird netbird < netbird-db-backup-YYYYMMDD.sql
```

### Re-run Ansible Playbook (Safe)

The playbook is **idempotent** - safe to run multiple times:

```bash
# Re-run deployment (preserves passwords and data)
ansible-playbook -i inventory/hosts.yml deploy-complete.yml

# Only update specific components
ansible-playbook -i inventory/hosts.yml deploy-complete.yml --tags keycloak
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Services not accessible via IP
**Problem**: Works with localhost but not external IP
**Solution**: This playbook fixes this by properly configuring internal vs external URLs

#### 2. Keycloak authentication fails
**Problem**: Token validation errors
**Solution**: Check that `NETBIRD_AUTH_AUTHORITY` uses external domain while internal services use container names

#### 3. Docker permission denied
**Problem**: User not in docker group
**Solution**: Re-run playbook or manually: `sudo usermod -aG docker $USER && newgrp docker`

### Debug Commands

```bash
# Check service health
ansible netbird -i inventory/hosts.yml -m uri -a "url=http://{{ ansible_default_ipv4.address }}:8080/realms/master"

# View configuration
ansible netbird -i inventory/hosts.yml -m shell -a "cat /home/your-name /netbird-deployment/config/netbird.env"

# Check Docker status
ansible netbird -i inventory/hosts.yml -m shell -a "docker ps"
```

## 📊 Monitoring

### Health Checks
- **PostgreSQL**: Built-in health checks
- **Keycloak**: HTTP endpoint monitoring  
- **NetBird services**: Container status monitoring

### Log Management
```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f keycloak
docker compose logs -f management
```

## 🔄 Multi-Machine Deployment

### High Availability Setup

```yaml
# inventory/hosts.yml
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: 192.168.1.100
          netbird_role: primary
        netbird-secondary:
          ansible_host: 192.168.1.101
          netbird_role: secondary
```

### Load Balancing
For production, add a load balancer in front of multiple NetBird instances:

```yaml
# Add to group_vars/all.yml
load_balancer_enabled: true
load_balancer_ip: "192.168.1.10"
```

## 📁 File Structure

```
netbird-ansible/
├── playbook.yml                    # Main playbook
├── inventory/
│   ├── hosts.yml                   # Server inventory
│   └── group_vars/
│       └── all.yml                 # Global variables
├── roles/
│   ├── system-preparation/         # System setup
│   │   └── tasks/
│   │       ├── main.yml
│   │       ├── check_requirements.yml
│   │       ├── remove_docker.yml
│   │       ├── install_docker.yml
│   │       ├── configure_firewall.yml
│   │       └── verify_installation.yml
│   ├── netbird-environment/        # Environment config
│   │   └── tasks/
│   │       ├── main.yml
│   │       ├── generate_passwords.yml
│   │       └── create_environment.yml
│   ├── netbird-deployment/         # Docker deployment
│   └── keycloak-configuration/     # Keycloak setup
├── templates/
│   ├── netbird.env.j2             # Environment template
│   ├── docker-compose.yml.j2      # Docker Compose template
│   ├── management.json.j2          # Management config
│   └── turnserver.conf.j2          # TURN server config
└── README.md                       # This file
```

## 🆘 Support

### Access Information
After successful deployment:

- **Keycloak Admin**: `http://YOUR_IP:8080/admin`
  - Username: `admin`
  - Password: Check `/home/your-name /netbird-deployment/config/IMPORTANT-PASSWORDS.txt`

- **NetBird Dashboard**: `http://YOUR_IP:8081`
  - Test user: `testuser` / `testpassword`

- **Management API**: `http://YOUR_IP:8082`

### Getting Help

1. **Check logs**: `docker compose logs -f`
2. **Verify configuration**: Review generated `.env` file
3. **Test connectivity**: Use provided debug commands
4. **Re-run playbook**: Safe to run multiple times
