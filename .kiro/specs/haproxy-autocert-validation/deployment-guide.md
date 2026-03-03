# HAProxy Deployment Guide

## Pre-Deployment Checklist

### 1. Infrastructure Requirements
- [ ] DNS A record for your domain pointing to HAProxy server IP
- [ ] Server with Ubuntu/Debian installed
- [ ] Docker and Docker Compose installed
- [ ] Ports 80, 443, 8404 accessible from internet
- [ ] SSH access to server

### 2. Ansible Requirements
- [ ] Ansible inventory configured with:
  - `reverse_proxy` group (HAProxy nodes)
  - `management` group (NetBird management nodes)
  - `relay` group (NetBird relay nodes)
- [ ] Required variables defined:
  - `netbird_domain`
  - `acme_email`
  - `haproxy_stats_password`

### 3. Recommended: Test with Let's Encrypt Staging
To avoid rate limits during testing, use staging:

```yaml
# In inventory or group_vars
acme_server: "https://acme-staging-v02.api.letsencrypt.org/directory"
```

## Deployment Steps

### Step 1: Verify Inventory
```bash
cd /path/to/project
ansible-inventory -i configuration/ansible/inventory/terraform_inventory.yaml --list
```

Verify output includes:
- `reverse_proxy` group with your HAProxy nodes
- `management` group with backend nodes
- `relay` group with relay nodes
- All required variables

### Step 2: Syntax Check
```bash
ansible-playbook configuration/ansible/playbooks/site.yml \
  -i configuration/ansible/inventory/terraform_inventory.yaml \
  --syntax-check
```

### Step 3: Dry Run (Check Mode)
```bash
ansible-playbook configuration/ansible/playbooks/site.yml \
  -i configuration/ansible/inventory/terraform_inventory.yaml \
  --tags haproxy \
  --check \
  --diff
```

Review the changes that would be made.

### Step 4: Deploy HAProxy
```bash
ansible-playbook configuration/ansible/playbooks/site.yml \
  -i configuration/ansible/inventory/terraform_inventory.yaml \
  --tags haproxy \
  -v
```

Watch for:
- ✅ All tasks complete successfully
- ✅ HAProxy container starts and becomes healthy
- ✅ ACME.sh container starts and becomes healthy
- ✅ Self-signed certificate created as fallback
- ✅ Firewall rules configured

### Step 5: Monitor Certificate Issuance
```bash
# SSH to HAProxy server
ssh ubuntu@<haproxy-ip>

# Watch ACME.sh logs
docker logs -f acme-sh

# Check startup log
tail -f /var/log/acme/startup.log
```

Certificate issuance should complete within 2-5 minutes.

## Verification Steps

### 1. Container Status
```bash
docker ps | grep -E "haproxy|acme"
```

Expected output:
```
haproxy    Up X minutes (healthy)
acme-sh    Up X minutes (healthy)
```

### 2. HAProxy Logs
```bash
docker logs haproxy | tail -50
```

Look for:
- No error messages
- Backend health check logs
- TLS handshake logs (after first connection)

### 3. Certificate Files
```bash
ls -lh /etc/haproxy/certs/
```

Expected files:
- `<domain>.pem` - Combined cert + key for HAProxy
- `<domain>.cert` - Certificate only
- `<domain>.key` - Private key
- `<domain>.fullchain` - Full certificate chain
- `<domain>.ca` - CA certificate

### 4. Certificate Validity
```bash
openssl x509 -in /etc/haproxy/certs/<domain>.pem -noout -text | grep -A 2 "Validity"
```

Check:
- Not Before date is recent
- Not After date is ~90 days in future
- Issuer is Let's Encrypt (or "Fake LE" for staging)

### 5. Stats Dashboard
```bash
curl http://localhost:8404/stats
```

Or open in browser: `http://<haproxy-ip>:8404/stats`

Check:
- All backends are listed
- Backends show as "DOWN" (expected if not deployed yet)
- ACME challenge backend shows as "UP"

### 6. HTTPS Connection Test
```bash
curl -v https://<domain>
```

Expected:
- TLS handshake succeeds
- Certificate is valid
- HTTP 503 error (expected if backends not deployed)

### 7. Certificate Chain Validation
```bash
openssl s_client -connect <domain>:443 -showcerts
```

Check:
- Certificate chain is complete
- No certificate verification errors
- TLS version is 1.2 or higher

### 8. HTTP to HTTPS Redirect
```bash
curl -I http://<domain>
```

Expected:
```
HTTP/1.1 301 Moved Permanently
Location: https://<domain>/
```

On MASTER node:
- Keepalived is active
- Virtual IP is assigned

On BACKUP node:
- Keepalived is active
- Virtual IP is NOT assigned

## Troubleshooting

### Issue: ACME.sh fails to issue certificate

**Symptoms**:
```
[ERROR] Verify error: Invalid response from http://<domain>/.well-known/acme-challenge/...
```

**Causes**:
1. DNS not pointing to server
2. Firewall blocking port 80
3. Another service using port 80

**Solutions**:
```bash
# Check DNS
dig <domain> +short

# Check port 80 is accessible
curl http://<domain>/.well-known/acme-challenge/test

# Check what's listening on port 80
sudo netstat -tlnp | grep :80
```

### Issue: HAProxy container won't start

**Symptoms**:
```
Error: container exited immediately
```

**Solutions**:
```bash
# Check HAProxy logs
docker logs haproxy

# Validate configuration
docker run --rm -v /etc/haproxy/haproxy.cfg:/etc/haproxy/haproxy.cfg:ro \
  haproxy:3.2-alpine haproxy -f /etc/haproxy/haproxy.cfg -c

# Check certificate exists
ls -la /etc/haproxy/certs/
```

### Issue: Certificate file not found

**Symptoms**:
```
[ALERT] Unable to load SSL certificate file '/etc/haproxy/certs/<domain>.pem'
```

**Solutions**:
```bash
# Check if self-signed cert was created
ls -la /etc/haproxy/certs/

# Manually create self-signed cert
openssl req -x509 -newkey rsa:2048 -keyout /tmp/key.pem -out /tmp/cert.pem \
  -days 365 -nodes -subj "/CN=<domain>/O=NetBird/C=US"
cat /tmp/cert.pem /tmp/key.pem > /etc/haproxy/certs/<domain>.pem
chmod 644 /etc/haproxy/certs/<domain>.pem

# Restart HAProxy
docker restart haproxy
```

### Issue: Backends show as DOWN

**Expected Behavior**: If management and relay nodes are not deployed yet, backends will show as DOWN in stats dashboard. This is normal.

**Verify**:
```bash
# Check if backend services are running
ssh <management-node-ip> "docker ps"
```

**Solutions**:
```bash
# Check Keepalived logs
journalctl -u keepalived -f

# Check Keepalived configuration
cat /etc/keepalived/keepalived.conf

# Verify VRRP traffic (should see multicast or unicast packets)
tcpdump -i <interface> vrrp

# Check priority (higher priority becomes MASTER)
grep priority /etc/keepalived/keepalived.conf
```

## Post-Deployment Tasks

### 1. Switch to Production Let's Encrypt
Once testing is complete, switch from staging to production:

```yaml
# Remove or comment out in inventory/group_vars
# acme_server: "https://acme-staging-v02.api.letsencrypt.org/directory"
```

Then force certificate renewal:
```bash
docker exec acme-sh /acme.sh/acme.sh --renew -d <domain> --force
```

### 2. Set Up Monitoring
- Monitor certificate expiry (alert 7 days before)
- Monitor HAProxy health checks

- Set up log aggregation

### 3. Test Failover (if HA enabled)
```bash
# On MASTER node, stop HAProxy
docker stop haproxy

# On BACKUP node, verify VIP is assigned
ip addr show | grep vip

# Verify traffic still works
curl https://<domain>

# Restart MASTER
docker start haproxy
```

### 4. Document Configuration
- Record which node is MASTER/BACKUP
- Document Virtual IP address
- Save stats dashboard password
- Document any custom configurations

## Next Steps

After HAProxy is deployed and verified:

1. Deploy NetBird management stack
2. Deploy NetBird relay servers
3. Test end-to-end routing through HAProxy
4. Verify gRPC, WebSocket, and HTTP routing
5. Load test the infrastructure
6. Set up monitoring and alerting

## Support

For issues:
1. Check HAProxy logs: `docker logs haproxy`
2. Check ACME logs: `cat /var/log/acme/startup.log`
3. Review this guide's troubleshooting section
4. Check HAProxy documentation: https://docs.haproxy.org/
5. Check ACME.sh documentation: https://github.com/acmesh-official/acme.sh
