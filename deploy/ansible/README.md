# NetBird Ansible Deployment

This Ansible playbook provides an idempotent, production-ready deployment of NetBird Control Plane with Keycloak identity provider.

## 🎯 Features

- **Idempotent deployment** - Safe to run multiple times
- **Multi-machine support** - Deploy across multiple servers
- **Network issue fixes** - Proper IP/domain configuration
- **Secure by default** - Encrypted passwords, firewall configuration
- **Production ready** - PostgreSQL, health checks, monitoring
- **Easy maintenance** - Role-based structure, automated updates

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

## 🚀 Quick Start

### Prerequisites

- Ubuntu/Debian server with sudo access
- Ansible 2.9+ installed on control machine
- SSH key access to target servers
- Minimum 2GB RAM, 2 CPU cores

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd netbird-ansible

# Edit inventory to match your servers
vim inventory/hosts.yml
```

### 2. Configure Variables

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
    netbird:
      hosts:
        netbird-primary:
          ansible_host: YOUR_SERVER_IP
          ansible_user: YOUR_USERNAME
```

### 3. Deploy NetBird

```bash
# Deploy everything
ansible-playbook -i inventory/hosts.yml playbook.yml

# Deploy to specific host
ansible-playbook -i inventory/hosts.yml playbook.yml --limit netbird-primary

# Deploy specific components
ansible-playbook -i inventory/hosts.yml playbook.yml --tags docker,environment
```

## 📋 Configuration Options

### Network Configuration

```yaml
# inventory/group_vars/all.yml
netbird_domain: "192.168.1.100"  # Your server IP or domain
netbird_dashboard_port: 8081
netbird_keycloak_port: 8080
netbird_management_port: 8082
```

### Security Configuration

```yaml
# Use Ansible Vault for production
use_ansible_vault: true
password_length: 32

# Firewall settings
firewall_enabled: true
```

### Service Versions

```yaml
netbird_version: "latest"
keycloak_version: "22.0"
postgres_version: "15"
```

## 🔐 Security Features

### Password Management
- **Automatic generation** of secure passwords
- **Preservation** of existing passwords on re-runs
- **Ansible Vault** support for production
- **Base64 encoding** for special characters

### Firewall Configuration
- **UFW firewall** automatically configured
- **Minimal attack surface** - only required ports open
- **SSH protection** maintained

### Network Security
- **Internal service communication** via Docker networks
- **External access** properly configured
- **CORS policies** correctly set

## 🔧 Maintenance

### View Service Status

```bash
# Check all services
ansible netbird -i inventory/hosts.yml -m shell -a "cd /home/usherking/netbird-deployment && docker compose ps"

# Check logs
ansible netbird -i inventory/hosts.yml -m shell -a "cd /home/usherking/netbird-deployment && docker compose logs keycloak"
```

### Update Services

```bash
# Update to latest versions
ansible-playbook -i inventory/hosts.yml playbook.yml --tags deployment

# Update specific service
ansible netbird -i inventory/hosts.yml -m shell -a "cd /home/usherking/netbird-deployment && docker compose pull keycloak && docker compose up -d keycloak"
```

### Backup and Restore

```bash
# Backup database
ansible netbird -i inventory/hosts.yml -m shell -a "cd /home/usherking/netbird-deployment && docker compose exec postgres pg_dump -U netbird netbird > backup.sql"

# Backup configuration
ansible netbird -i inventory/hosts.yml -m fetch -a "src=/home/usherking/netbird-deployment/config/ dest=./backups/"
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
ansible netbird -i inventory/hosts.yml -m shell -a "cat /home/usherking/netbird-deployment/config/netbird.env"

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
  - Password: Check `/home/usherking/netbird-deployment/config/IMPORTANT-PASSWORDS.txt`

- **NetBird Dashboard**: `http://YOUR_IP:8081`
  - Test user: `testuser` / `testpassword`

- **Management API**: `http://YOUR_IP:8082`

### Getting Help

1. **Check logs**: `docker compose logs -f`
2. **Verify configuration**: Review generated `.env` file
3. **Test connectivity**: Use provided debug commands
4. **Re-run playbook**: Safe to run multiple times

## 🔄 Migration from Shell Scripts

If you have an existing NetBird deployment using the shell scripts:

1. **Backup existing data**:
   ```bash
   cp -r ~/netbird-deployment ~/netbird-deployment.backup
   ```

2. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

3. **The playbook will**:
   - Preserve existing passwords
   - Maintain database data
   - Update configuration for proper IP handling
   - Add idempotency and monitoring

## 🎉 What's Fixed

This Ansible playbook solves the key issues from your shell script deployment:

✅ **IP Address Issues**: Proper separation of internal/external URLs
✅ **Idempotency**: Safe to run multiple times
✅ **Multi-machine**: Easy deployment across servers  
✅ **Maintenance**: Structured, maintainable code
✅ **Security**: Encrypted secrets, proper firewall
✅ **Monitoring**: Health checks and logging
✅ **Documentation**: Self-documenting infrastructure
