# 🚀 NetBird Ansible Deployment Guide

This guide will walk you through deploying NetBird Control Plane using the Ansible playbook, which solves the IP address issues from your shell script deployment and provides idempotent, multi-machine support.

## 🎯 What This Playbook Fixes

✅ **IP Address Issues**: Proper separation of internal/external URLs  
✅ **Idempotency**: Safe to run multiple times without breaking  
✅ **Multi-machine Support**: Easy deployment across multiple servers  
✅ **Automated Configuration**: No manual Keycloak setup required  
✅ **Password Management**: Secure generation and preservation  
✅ **Health Monitoring**: Built-in service health checks  

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or Debian 11+
- **RAM**: Minimum 2GB (4GB recommended)
- **CPU**: 2+ cores
- **Disk**: 10GB+ free space
- **Network**: Internet access for Docker images

### Control Machine (where you run Ansible)
```bash
# Install Ansible
sudo apt update
sudo apt install ansible

# Verify installation
ansible --version
```

### Target Server(s)
- SSH access with sudo privileges
- SSH key authentication configured
- User account with docker group membership (will be configured by playbook)

## 🚀 Quick Start Deployment

### Step 1: Prepare the Playbook

```bash
# Navigate to the ansible directory
cd /home/usherking/projects/test/control-plane/netbird/netbird/ansible

# Make sure all files are present
ls -la
```

### Step 2: Configure Your Inventory

Edit `inventory/hosts.yml` to match your setup:

```yaml
---
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: 192.168.4.123  # Your server IP
          ansible_user: usherking      # Your username
          netbird_role: primary
```

### Step 3: Test Connectivity

```bash
# Test SSH connection
ansible -i inventory/hosts.yml netbird -m ping

# Expected output:
# netbird-primary | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### Step 4: Deploy NetBird

```bash
# Full deployment (recommended for first run)
ansible-playbook -i inventory/hosts.yml playbook.yml

# Or deploy with verbose output
ansible-playbook -i inventory/hosts.yml playbook.yml -v
```

## 🔧 Advanced Deployment Options

### Deploy Specific Components

```bash
# Only system preparation
ansible-playbook -i inventory/hosts.yml playbook.yml --tags system

# Only environment configuration
ansible-playbook -i inventory/hosts.yml playbook.yml --tags environment

# Only Docker deployment
ansible-playbook -i inventory/hosts.yml playbook.yml --tags deployment

# Only Keycloak configuration
ansible-playbook -i inventory/hosts.yml playbook.yml --tags keycloak
```

### Deploy to Specific Hosts

```bash
# Deploy to single host
ansible-playbook -i inventory/hosts.yml playbook.yml --limit netbird-primary

# Deploy to multiple hosts
ansible-playbook -i inventory/hosts.yml playbook.yml --limit "netbird-primary,netbird-secondary"
```

### Custom Variables

```bash
# Override domain
ansible-playbook -i inventory/hosts.yml playbook.yml -e "netbird_domain=netbird.example.com"

# Skip Keycloak configuration
ansible-playbook -i inventory/hosts.yml playbook.yml -e "configure_keycloak=false"

# Use different NetBird version
ansible-playbook -i inventory/hosts.yml playbook.yml -e "netbird_version=v0.24.0"
```

## 📊 Monitoring Deployment Progress

The playbook provides detailed progress information:

### System Preparation Phase
```
TASK [system-preparation : Check system requirements] *************************
ok: [netbird-primary]

TASK [system-preparation : Install Docker] ************************************
changed: [netbird-primary]
```

### Environment Configuration Phase
```
TASK [netbird-environment : Generate secure passwords] ************************
ok: [netbird-primary]

TASK [netbird-environment : Create environment configuration] *****************
changed: [netbird-primary]
```

### Service Deployment Phase
```
TASK [netbird-deployment : Deploy NetBird services] ***************************
changed: [netbird-primary]

TASK [netbird-deployment : Wait for services to be ready] *********************
ok: [netbird-primary]
```

### Keycloak Configuration Phase
```
TASK [keycloak-configuration : Create NetBird realm] **************************
changed: [netbird-primary]

TASK [keycloak-configuration : Create NetBird clients] ************************
changed: [netbird-primary]
```

## 🎉 Post-Deployment Verification

### 1. Check Service Status

```bash
# On the target server
cd /home/usherking/netbird-deployment
./scripts/check-status.sh
```

Expected output:
```
=== NetBird Service Status ===
NAME                    IMAGE                           STATUS
netbird-postgres        postgres:15                     Up 2 minutes
netbird-keycloak        quay.io/keycloak/keycloak:22.0  Up 2 minutes
netbird-management      netbirdio/management:latest     Up 1 minute
netbird-dashboard       netbirdio/dashboard:latest      Up 1 minute

=== Service Health ===
Keycloak: 200
Dashboard: 200
Management API: 200
```

### 2. Access Web Interfaces

- **NetBird Dashboard**: `http://YOUR_IP:8081`
- **Keycloak Admin**: `http://YOUR_IP:8080/admin`

### 3. Test Login

Use the test credentials from `/home/usherking/netbird-deployment/config/IMPORTANT-PASSWORDS.txt`:
- Username: `testuser`
- Password: `testpassword`

## 🔐 Security Information

### Password Files

The playbook creates secure password files:

```bash
# View all passwords (secure location)
cat /home/usherking/netbird-deployment/config/IMPORTANT-PASSWORDS.txt

# Initial generated passwords
cat /home/usherking/netbird-deployment/config/PASSWORDS-GENERATED.txt
```

### Key Security Features

- **Automatic password generation** with secure randomization
- **Password preservation** on subsequent runs
- **File permissions** set to 600 (owner read/write only)
- **Firewall configuration** with minimal attack surface
- **Container isolation** via Docker networks

## 🔄 Maintenance Operations

### Update NetBird Services

```bash
# On target server
cd /home/usherking/netbird-deployment
./scripts/update.sh
```

### Backup Configuration and Data

```bash
# On target server
cd /home/usherking/netbird-deployment
./scripts/backup.sh
```

### Re-run Ansible Playbook (Idempotent)

```bash
# Safe to run multiple times
ansible-playbook -i inventory/hosts.yml playbook.yml
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f keycloak
docker compose logs -f management
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. "Connection refused" errors
**Problem**: Services not accessible via IP address  
**Solution**: This playbook fixes this by properly configuring external vs internal URLs

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
