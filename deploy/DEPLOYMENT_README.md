# Keycloak Deployment for NetBird

## Overview
This Ansible playbook deploys a complete Keycloak stack with:
- PostgreSQL database
- Keycloak 25.0 server
- Caddy reverse proxy with automatic HTTPS

## Configuration

### Inventory
The deployment targets the host defined in `inventory.ini`:
- **Host**: 10.165.218.150
- **User**: ubuntu
- **SSH Key**: ~/.ssh/ansible

### Domain Setup
Using **nip.io** for local IP-based domain resolution:
- **Domain**: 10.165.218.150.nip.io
- This allows HTTPS without DNS configuration
- Caddy will generate self-signed certificates automatically

### Current Settings (group_vars/keycloak.yml)
```yaml
keycloak_deploy_mode: true
keycloak_host: "10.165.218.150.nip.io"
keycloak_admin_user: "admin"
keycloak_admin_password: "TestAdmin123!"
keycloak_db_password: "TestDB123!"
keycloak_realm: "netbird"
keycloak_client_netbird: "netbird-client"
keycloak_client_netbird_backend: "netbird-backend"
```

## Deployment Steps

### 1. Pre-flight Check
```bash
# Test SSH connectivity
ansible -i inventory.ini keycloak -m ping

# Dry-run to check what will be done
ansible-playbook -i inventory.ini deploy_keycloak.yml --check
```

### 2. Deploy
```bash
# Full deployment
ansible-playbook -i inventory.ini deploy_keycloak.yml

# With verbose output
ansible-playbook -i inventory.ini deploy_keycloak.yml -v
```

### 3. Post-Deployment

#### Access Points
- **Keycloak Home**: https://10.165.218.150.nip.io
- **Admin Console**: https://10.165.218.150.nip.io/admin
- **Admin Credentials**: admin / TestAdmin123!

#### OIDC Endpoints
- **Master Realm**: https://10.165.218.150.nip.io/realms/master/.well-known/openid-configuration
- **NetBird Realm**: https://10.165.218.150.nip.io/realms/netbird/.well-known/openid-configuration

#### Configuration File
After deployment, client secrets are saved to:
```
/opt/keycloak/netbird-config.env
```

## Architecture

### Docker Compose Stack
```
┌─────────────────────────────────────────┐
│  Caddy (Reverse Proxy)                  │
│  Ports: 80, 443                         │
│  - Automatic HTTPS                       │
│  - Self-signed cert for .nip.io         │
└──────────────┬──────────────────────────┘
               │ Proxies to
               ▼
┌─────────────────────────────────────────┐
│  Keycloak                               │
│  Port: 8080 (internal)                  │
│  - Edge proxy mode                       │
│  - Accepts X-Forwarded headers          │
└──────────────┬──────────────────────────┘
               │ Connects to
               ▼
┌─────────────────────────────────────────┐
│  PostgreSQL 15                          │
│  Port: 5432 (internal)                  │
│  - Persistent volume                     │
└─────────────────────────────────────────┘
```

### Network
All services run on the `keycloak_network` bridge network, allowing container-to-container communication by name.

### Volumes
- `keycloak_postgres_data`: Database persistence
- `keycloak_data`: Keycloak application data
- `caddy_data`: Caddy certificates and data
- `caddy_config`: Caddy configuration
- `caddy_logs`: Caddy access logs

## NetBird Integration

### Realm Configuration
The playbook automatically creates:
1. **NetBird Realm** with security settings
2. **Public Client** (`netbird-client`) for UI/CLI
   - PKCE enabled
   - Device authorization grant enabled
   - Redirect URIs configured
3. **Service Account Client** (`netbird-backend`)
   - Client credentials for management API
   - `view-users` and `manage-users` roles assigned

### For NetBird Deployment
Use the configuration saved in `/opt/keycloak/netbird-config.env`:
```bash
# On the Keycloak host
cat /opt/keycloak/netbird-config.env
```

Key values needed:
- `OIDC_CONFIGURATION_ENDPOINT`
- `FRONTEND_CLIENT_ID`
- `BACKEND_CLIENT_ID`
- `BACKEND_CLIENT_SECRET`
- `BACKEND_ADMIN_ENDPOINT`

## Troubleshooting

### Check Service Status
```bash
# SSH to the host
ssh -i ~/.ssh/ansible ubuntu@10.165.218.150

# View running containers
docker ps

# View logs
docker logs keycloak
docker logs caddy
docker logs keycloak_postgres

# Check compose status
cd /opt/keycloak
docker compose ps
docker compose logs -f
```

### Restart Services
```bash
cd /opt/keycloak
docker compose restart
```

### SSL Certificate Warning
When accessing https://10.165.218.150.nip.io, you'll see a certificate warning because:
- Caddy uses self-signed certificates for .nip.io domains
- This is expected for local/internal deployments
- Accept the certificate to proceed

For production, use a real domain name with DNS, and Caddy will automatically obtain Let's Encrypt certificates.

## Security Notes

⚠️ **Current Configuration is for Testing Only**

For production:
1. Change admin and database passwords
2. Use Ansible Vault to encrypt secrets
3. Use a real domain name with proper DNS
4. Enable firewall rules (UFW/iptables)
5. Consider additional security hardening
6. Set up proper backups
7. Configure monitoring

### Using Ansible Vault
```bash
# Encrypt the group_vars file
ansible-vault encrypt group_vars/keycloak.yml

# Run playbook with vault
ansible-playbook -i inventory.ini deploy_keycloak.yml --ask-vault-pass
```

## Maintenance

### Backup
```bash
# Backup PostgreSQL
docker exec keycloak_postgres pg_dump -U keycloak keycloak > keycloak-backup.sql

# Backup Keycloak data volume
docker run --rm -v keycloak_data:/data -v $(pwd):/backup alpine tar czf /backup/keycloak-data.tar.gz /data
```

### Updates
To update Keycloak version:
1. Edit `group_vars/keycloak.yml` - change `keycloak_image`
2. Re-run playbook: `ansible-playbook -i inventory.ini deploy_keycloak.yml`

### Clean Slate
To completely remove and redeploy:
```bash
ssh -i ~/.ssh/ansible ubuntu@10.165.218.150
cd /opt/keycloak
docker compose down -v  # Removes volumes (data will be lost!)
rm -rf /opt/keycloak
# Then re-run the playbook
```
