# 🚀 NetBird Control Plane - Complete Deployment Guide

## 📖 Overview

This guide provides a **production-ready** deployment of NetBird Control Plane using Ansible. All critical OAuth, encryption, and device authorization issues have been resolved.

### ✅ What's Fixed and Working

- **OAuth Client Secrets**: Proper generation and synchronization with Keycloak
- **Encryption Keys**: Correct AES-256 key size (32 characters)
- **Device Authorization Flow**: OAuth 2.0 Device Grant enabled for CLI peers
- **Token Audience**: Proper audience mappers for authentication
- **Network Configuration**: Internal Docker vs External IP handling
- **Keycloak Integration**: Full automation with proper realm and client setup
- **Idempotent Deployment**: Safe to run multiple times

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or Debian 11+
- **RAM**: Minimum 2GB (4GB recommended)
- **CPU**: 2+ cores
- **Disk**: 10GB+ free space
- **Network**: Internet access for Docker images

### Control Machine (where you run Ansible)
```bash
# Install Ansible (on your control machine)
sudo apt update
sudo apt install ansible

# Verify installation (Ansible 2.9+ required)
ansible --version
```

### Target Server Requirements
- Ubuntu 20.04+ or Debian 11+
- SSH access with sudo privileges
- SSH key-based authentication (recommended)
- Static IP address or reliable DHCP reservation
- Ports available: 8080 (Keycloak), 8081 (Dashboard), 8082 (Management API), 10000 (Signal), 3478 (STUN), 3479 (Relay)

---

## 🚀 Deployment Steps

### Step 1: Clone or Navigate to Ansible Directory

```bash
# Navigate to the ansible deployment directory
cd /path/to/netbird/deploy/ansible

# Verify all required files exist
ls -la
# Expected: inventory/, roles/, templates/, deploy-complete.yml
```

### Step 2: Configure Your Inventory

Edit `inventory/hosts.yml` with your server details:

```yaml
---
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: 192.168.1.229    # YOUR SERVER IP
          ansible_user: yourusername      # YOUR SSH USERNAME
          netbird_role: primary
      vars:
        netbird_external_domain: "192.168.1.229"  # Use IP or domain
        netbird_base_dir: "/home/yourusername/netbird-deployment"
```

**Important**: Replace `192.168.1.229` and `yourusername` with your actual values.

### Step 3: Test SSH Connectivity

```bash
# Test connection to your server
ansible -i inventory/hosts.yml netbird -m ping

# Expected output:
# netbird-primary | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

If this fails:
```bash
# Test SSH manually first
ssh yourusername@192.168.1.229

# Or use password authentication
ansible -i inventory/hosts.yml netbird -m ping --ask-pass
```

### Step 4: Run Complete Deployment

```bash
# Deploy everything (first-time deployment)
ansible-playbook -i inventory/hosts.yml deploy-complete.yml

# With verbose output for debugging
ansible-playbook -i inventory/hosts.yml deploy-complete.yml -v
```

**Deployment Progress**:
1. ✅ System preparation (Docker, firewall, dependencies)
2. ✅ Environment configuration (passwords, certificates)
3. ✅ Docker Compose setup
4. ✅ Service deployment (PostgreSQL, Keycloak, Management, Dashboard)
5. ✅ Keycloak configuration (realm, clients, users)
6. ✅ Client secret synchronization

**Duration**: 10-15 minutes depending on network speed.

---

## ✅ Post-Deployment Verification

### 1. Check Service Status

On your server, verify all services are running:

```bash
cd ~/netbird-deployment
sudo docker compose ps
```

**Expected output** (all services should show "Up" status):
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

### 2. Access Web Interfaces

**NetBird Dashboard**:
```
http://YOUR_SERVER_IP:8081
```

**Keycloak Admin Console**:
```
http://YOUR_SERVER_IP:8080/admin
Realm: master
Username: admin
Password: (found in ~/netbird-deployment/.env as KEYCLOAK_ADMIN_PASSWORD)
```

### 3. Find Your Credentials

All generated passwords are stored in:
```bash
cat ~/netbird-deployment/config/PASSWORDS-GENERATED.txt
```

This file contains:
- Keycloak admin password
- PostgreSQL password
- All generated secrets

### 4. Test Dashboard Login

1. Open `http://YOUR_SERVER_IP:8081` in browser
2. Click "Login"
3. You'll be redirected to Keycloak
4. Login with Keycloak credentials
5. You should see the NetBird dashboard

---

## 👥 Adding Peers (Clients)

### Install NetBird Client on Peer Machine

```bash
# On Ubuntu/Debian
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Verify installation
netbird version
```

### Register Peer with Management Server

```bash
# Replace YOUR_SERVER_IP with your control plane IP
netbird up --management-url http://YOUR_SERVER_IP:8082
```

**What happens**:
1. Command displays an SSO login URL
2. Open the URL in your browser
3. Login with Keycloak credentials
4. Peer automatically registers and connects
5. Peer appears in the dashboard

**Example**:
```bash
netbird up --management-url http://192.168.1.229:8082

Please do the SSO login in your browser.
If your browser didn't open automatically, use this URL:

http://192.168.1.229:8080/realms/netbird/device?user_code=ABCD-EFGH
```

### Verify Peer Connection

On the peer machine:
```bash
# Check status
netbird status

# View peer details
netbird status --detail
```

In the dashboard:
- Navigate to "Peers" section
- Your new peer should be listed with status "Online"

---

## 🔧 Maintenance & Operations

### View Service Logs

```bash
cd ~/netbird-deployment

# All services
sudo docker compose logs -f

# Specific service
sudo docker compose logs -f management
sudo docker compose logs -f keycloak
sudo docker compose logs -f dashboard

# Last 50 lines
sudo docker compose logs --tail 50 management
```

### Restart Services

```bash
cd ~/netbird-deployment

# Restart all services
sudo docker compose restart

# Restart specific service
sudo docker compose restart management
sudo docker compose restart keycloak
```

### Update NetBird Services

```bash
cd ~/netbird-deployment

# Pull latest images
sudo docker compose pull

# Restart with new images
sudo docker compose up -d
```

### Backup Important Data

```bash
# Backup configuration and environment
cp -r ~/netbird-deployment/config ~/netbird-deployment-backup-$(date +%Y%m%d)
cp ~/netbird-deployment/.env ~/netbird-deployment-backup-$(date +%Y%m%d)/

# Backup database (PostgreSQL)
cd ~/netbird-deployment
sudo docker compose exec -T postgres pg_dump -U netbird netbird > backup-$(date +%Y%m%d).sql
```

### Re-run Ansible Playbook (Idempotent)

```bash
# Safe to run anytime - preserves existing passwords and data
ansible-playbook -i inventory/hosts.yml deploy-complete.yml
```

---

## 🚫 Common Issues & Solutions

### Issue 1: "crypto/aes: invalid key size 44"

**Error**: Management service fails to start with encryption key error

**Cause**: Old deployments used 44-character base64 keys, but AES-256 requires exactly 32 characters

**Solution**: Already fixed in current playbook. If upgrading from old deployment:
```bash
# Regenerate with correct 32-character key
cd ~/netbird-deployment
python3 -c "import random, string; print(''.join(random.choices(string.ascii_letters + string.digits, k=32)))"
# Update NETBIRD_DATASTORE_ENC_KEY in .env with generated value
# Regenerate management.json using the Ansible template
```

### Issue 2: "no provider found in the protocol for keycloak"

**Error**: Peer registration fails with provider error

**Cause**: DeviceAuthorizationFlow provider was set to "keycloak" instead of "hosted"

**Solution**: Already fixed - playbook now sets `Provider: "hosted"` in management.json.j2

### Issue 3: "OAuth 2.0 Device Authorization Grant flow disabled"

**Error**: `error: Client is not allowed to initiate OAuth 2.0 Device Authorization Grant`

**Cause**: Device client missing OAuth 2.0 Device Grant attribute

**Solution**: Already fixed - playbook now enables this attribute automatically.

Manual fix if needed:
```bash
cd ~/netbird-deployment
sudo docker compose exec keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password $(grep KEYCLOAK_ADMIN_PASSWORD .env | cut -d'=' -f2)

# Get device client ID
sudo docker compose exec keycloak /opt/keycloak/bin/kcadm.sh get clients --target-realm netbird --query clientId=netbird-device --fields id

# Enable device flow (replace CLIENT_ID with actual ID from above)
sudo docker compose exec keycloak /opt/keycloak/bin/kcadm.sh update clients/CLIENT_ID --target-realm netbird -s 'attributes."oauth2.device.authorization.grant.enabled"=true'
```

### Issue 4: "invalid JWT token audience field"

**Error**: Peer authentication fails with audience validation error

**Cause**: Device client tokens don't include correct audience claim

**Solution**: Already fixed - playbook adds audience mapper automatically.

Manual fix if needed:
```bash
# Get client ID first (see Issue 3)
# Then add audience mapper
sudo docker compose exec keycloak /opt/keycloak/bin/kcadm.sh create clients/CLIENT_ID/protocol-mappers/models --target-realm netbird --set name=audience-mapper --set protocol=openid-connect --set protocolMapper=oidc-audience-mapper --set 'config."included.client.audience"=netbird-client' --set 'config."access.token.claim"=true' --set 'config."id.token.claim"=false'
```

### Issue 5: "context deadline exceeded" when adding peer

**Error**: `Error: unable to get daemon status: rpc error: code = FailedPrecondition desc = failed connecting to Management Service`

**Cause**: Network connectivity issue between peer and control plane

**Solutions**:
```bash
# On peer machine, test connectivity
ping YOUR_SERVER_IP
telnet YOUR_SERVER_IP 8082
curl http://YOUR_SERVER_IP:8082/api/peers

# Check firewall on server
sudo ufw status
sudo ufw allow 8082/tcp

# Check if peer and server are on different networks
# May need port forwarding or VPN

# Restart netbird daemon on peer
sudo systemctl restart netbird
```

### Issue 6: Dashboard shows "Oops, something went wrong"

**Error**: Dashboard accessible but shows error after Keycloak login

**Cause**: Client secret mismatch between management.json and Keycloak

**Solution**: Already fixed - playbook synchronizes secrets automatically using `update_client_secrets.yml`

### Issue 7: Docker Hub Rate Limiting (503 errors)

**Error**: `ERROR: HTTP code 503 while pulling images`

**Solutions**:
```bash
# Option 1: Wait for rate limit reset (6 hours)

# Option 2: Authenticate with Docker Hub
docker login
# Then re-run playbook

# Option 3: Use mirror or cache
# Configure in /etc/docker/daemon.json
```

### Issue 8: Port Already in Use

**Error**: Services fail to start due to port conflicts

**Check what's using the ports**:
```bash
sudo netstat -tlnp | grep -E ':(8080|8081|8082|10000)'
```

**Solution**:
```bash
# Stop conflicting services or change NetBird ports
# Edit inventory/group_vars/all.yml
netbird_keycloak_port: 8080    # Change if needed
netbird_dashboard_port: 8081   # Change if needed
netbird_management_port: 8082  # Change if needed
```

---

## 📑 Important File Locations

```
~/netbird-deployment/
├── .env                          # Main environment file
├── docker-compose.yml             # Docker services configuration
├── management.json                # NetBird management config
├── turnserver.conf                # TURN server config
└── config/
    ├── netbird.env                # Environment backup
    └── PASSWORDS-GENERATED.txt    # All generated passwords
```

### Configuration Files

**Environment Variables** (`~/netbird-deployment/.env`):
- All service configuration
- Database credentials
- Keycloak settings
- Client secrets
- Encryption keys

**Management Configuration** (`~/netbird-deployment/management.json`):
- OAuth/OIDC settings
- Keycloak integration
- Device authorization flow
- Token endpoints

---

## 🛠️ Advanced Configuration

### Changing Domain or IP Address

1. Update `inventory/hosts.yml`:
```yaml
netbird_external_domain: "your.new.domain.com"
```

2. Re-run playbook:
```bash
ansible-playbook -i inventory/hosts.yml deploy-complete.yml
```

### Using a Custom Domain (HTTPS)

For production with HTTPS:

1. Get SSL certificates (Let's Encrypt recommended)
2. Configure reverse proxy (Nginx/Traefik)
3. Update `inventory/group_vars/all.yml`:
```yaml
netbird_protocol: https
netbird_external_domain: "netbird.yourdomain.com"
```

### Customizing Ports

Edit `inventory/group_vars/all.yml`:
```yaml
netbird_keycloak_port: 8080
netbird_dashboard_port: 8081
netbird_management_port: 8082
netbird_signal_port: 10000
netbird_stun_port: 3478
netbird_relay_port: 3479
```

Then re-run deployment.

#### 2. Ansible connection failures
```bash
# Check SSH connectivity
ssh usherking@192.168.4.123

# Verify SSH key
ssh-add -l

# Test with password authentication
ansible-playbook -i inventory/hosts.yml playbook.yml --ask-pass
```

#### 3. Docker permission denied
```bash
# Re-run system preparation
ansible-playbook -i inventory/hosts.yml playbook.yml --tags system

# Or manually fix on target server
sudo usermod -aG docker $USER
newgrp docker
```

#### 4. Keycloak configuration fails
```bash
# Re-run only Keycloak configuration
ansible-playbook -i inventory/hosts.yml playbook.yml --tags keycloak

# Check Keycloak logs
docker compose logs keycloak
```

#### 5. Services fail to start
```bash
# Check system resources
free -h
df -h

# Restart services
docker compose restart

# Check for port conflicts
sudo netstat -tlnp | grep -E ':(8080|8081|8082)'
```

### Debug Commands

```bash
# Check Ansible facts
ansible -i inventory/hosts.yml netbird -m setup

# Test specific tasks
ansible-playbook -i inventory/hosts.yml playbook.yml --tags system --check

# Dry run (no changes)
ansible-playbook -i inventory/hosts.yml playbook.yml --check
```

## 🔄 Multi-Machine Deployment

### High Availability Setup

For production environments, deploy across multiple servers:

```yaml
# inventory/hosts.yml
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: 192.168.4.123
          netbird_role: primary
        netbird-secondary:
          ansible_host: 192.168.4.124
          netbird_role: secondary
        netbird-tertiary:
          ansible_host: 192.168.4.125
          netbird_role: tertiary
```

Deploy to all servers:
```bash
ansible-playbook -i inventory/hosts.yml playbook.yml
```

### Load Balancer Configuration

Add a load balancer in front of multiple NetBird instances:

```yaml
# inventory/group_vars/all.yml
load_balancer_enabled: true
load_balancer_vip: "192.168.4.100"
```

## 📈 Performance Tuning

### Resource Optimization

```yaml
# inventory/group_vars/all.yml
# Adjust for your environment
postgres_max_connections: 200
keycloak_heap_size: "1g"
netbird_log_level: "info"
```

### Monitoring Setup

```bash
# Enable backup automation
ansible-playbook -i inventory/hosts.yml playbook.yml -e "backup_enabled=true"

# Set backup retention
ansible-playbook -i inventory/hosts.yml playbook.yml -e "backup_retention_days=14"
```

## 🆘 Getting Help

### Log Locations

- **Ansible logs**: Terminal output during playbook run
- **Docker logs**: `docker compose logs -f`
- **System logs**: `/var/log/syslog`
- **NetBird logs**: Container logs via Docker

### Support Resources

1. **Check service status**: `./scripts/check-status.sh`
2. **Review configuration**: `cat config/netbird.env`
3. **Test connectivity**: `curl http://YOUR_IP:8080/realms/master`
4. **Re-run playbook**: Safe to run multiple times

### Migration from Shell Scripts

If migrating from your existing shell script deployment:

1. **Backup existing deployment**:
   ```bash
   cp -r ~/netbird-deployment ~/netbird-deployment.backup
   ```

2. **Run Ansible playbook**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

3. **Verify migration**:
   - Existing passwords are preserved
   - Database data is maintained
   - Configuration is updated for proper IP handling

## 🎊 Success!

After successful deployment, you should have:

✅ **Working NetBird Control Plane** accessible via your server's IP address  
✅ **Keycloak Identity Provider** fully configured with NetBird realm  
✅ **Test user account** ready for immediate use  
✅ **Management scripts** for maintenance and updates  
✅ **Backup system** for data protection  
✅ **Idempotent deployment** that can be safely re-run  

Your NetBird deployment is now ready for production use with proper IP address handling and multi-machine support!
