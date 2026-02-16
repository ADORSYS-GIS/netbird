# Troubleshooting Guide

Diagnose and resolve common issues with the NetBird deployment.

## Diagnostic Decision Tree

```mermaid
graph TD
    A[Issue Detected] --> B{Can check HTTPS?}
    B -->|No| C[Check DNS & Caddy]
    B -->|Yes| D{Dashboard Loads?}
    D -->|No| E[Check Management Service]
    D -->|Yes| F{Agents Can Connect?}
    F -->|No| G[Check Signal/Relay]
    F -->|Yes| H[Check Logs]

    C --> C1[Ping Domain]
    C --> C2[Check Caddy Logs]
    C --> C3[Check Security Groups (80/443)]

    E --> E1[Check Docker Containers]
    E --> E2[Check Database Connection]
    E --> E3[Check Keycloak Auth]

    G --> G1[Check Turn/Stun (UDP 3478)]
    G --> G2[Check Signal Websocket]
```

## Common Issues

### 1. "502 Bad Gateway" on Dashboard

**Symptoms**: Accessing `https://netbird.yourdomain.com` returns a white 502 error page.

**Cause**: Caddy cannot communicate with the backend Management service.

**Diagnosis**:

1. **Check Caddy logs**:
   ```bash
   ssh reverse-proxy
   docker logs caddy 2>&1 | tail -50
   ```
   
   **Expected output if working**:
   ```
   {"level":"info","ts":1234567890,"msg":"reverse proxy upstream","upstream":"http://10.0.1.10:80"}
   ```
   
   **Error pattern to look for**:
   ```
   dial tcp 10.0.1.10:80: connect: connection refused
   dial tcp 10.0.1.10:80: i/o timeout
   ```

2. **Verify Management service is running**:
   ```bash
   ssh management-node
   docker ps | grep netbird
   ```
   
   **Expected output**:
   ```
   CONTAINER ID   IMAGE                    STATUS
   abc123def456   netbird/management:...   Up 2 hours
   def789ghi012   netbird/signal:...       Up 2 hours
   ```

3. **Test network connectivity**:
   ```bash
   # From reverse-proxy node
   ping -c 3 10.0.1.10
   curl -v http://10.0.1.10:80/health
   ```
   
   **Expected output**:
   ```
   {"status":"ok"}
   ```

4. **Check UFW rules**:
   ```bash
   ssh management-node
   sudo ufw status numbered
   ```
   
   **Expected output** (should include reverse proxy IP):
   ```
   [ 1] 80/tcp          ALLOW IN    10.0.1.12  # Reverse Proxy
   [ 2] 22/tcp          ALLOW IN    Anywhere
   ```

**Solutions**:

- **If containers not running**: 
  ```bash
  cd /opt/netbird
  docker-compose up -d
  ```

- **If UFW blocking**: 
  ```bash
  sudo ufw allow from 10.0.1.12 to any port 80 comment 'Reverse Proxy'
  sudo ufw reload
  ```

- **If service not binding to correct IP**: Check `/opt/netbird/docker-compose.yml` and verify ports configuration.

### 2. Agents Cannot Connect to NetBird

**Symptoms**: Running `netbird up` on client fails with:
```
Error: failed to connect to signal server: context deadline exceeded
```

**Cause**: Signal service unreachable, GRPC blocked, or TURN/STUN issues.

**Diagnosis**:

1. **Test Signal endpoint**:
   ```bash
   curl -v https://netbird.yourdomain.com:443
   ```
   
   **Expected output**:
   ```
   < HTTP/2 200
   < content-type: application/grpc
   ```

2. **Check Signal service**:
   ```bash
   ssh management-node
   docker logs netbird-signal 2>&1 | tail -50
   ```
   
   **Look for errors**:
   ```
   level=error msg="failed to start signal server"
   level=error msg="database connection failed"
   ```

3. **Verify TURN/STUN ports**:
   ```bash
   # From client machine
   nc -vzu netbird.yourdomain.com 3478
   ```
   
   **Expected output**:
   ```
   Connection to netbird.yourdomain.com 3478 port [udp/stun] succeeded!
   ```

4. **Check Caddy GRPC configuration**:
   ```bash
   ssh reverse-proxy
   cat /etc/caddy/Caddyfile | grep -A5 "grpc"
   ```
   
   **Expected configuration**:
   ```
   reverse_proxy /signalexchange.SignalExchange/* h2c://10.0.1.10:10000
   ```

**Solutions**:

- **If TURN/STUN blocked**: Ensure UDP 3478 is open in cloud security groups
  ```bash
  # Check AWS security group
  aws ec2 describe-security-groups --group-ids sg-xxx
  ```

- **If Signal service down**: Restart the service
  ```bash
  docker-compose -f /opt/netbird/docker-compose.yml restart netbird-signal
  ```

- **If GRPC routing issue**: Reconfigure Caddy (run Ansible playbook)
  ```bash
  cd configuration/ansible
  ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml --tags caddy
  ```

### 3. Deployment Playbook Fails on SSH

**Symptoms**: Ansible cannot connect to hosts:
```
fatal: [management-node]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Cause**: SSH key issues, security group blocking, or incorrect inventory.

**Diagnosis**:

1. **Verify SSH connectivity**:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<management-ip> -v
   ```
   
   **Expected**: Successful login prompt

2. **Check security group rules**:
   ```bash
   # Get your current IP
   curl -4 ifconfig.me
   
   # Verify it's in admin_cidr_blocks in terraform.tfvars
   grep admin_cidr_blocks infrastructure/ansible-stack/terraform.tfvars
   ```
   
   **Expected**:
   ```
   admin_cidr_blocks = ["YOUR_IP/32"]
   ```

3. **Test with verbose Ansible**:
   ```bash
   ansible -i configuration/ansible/inventory/terraform_inventory.yaml all -m ping -vvv
   ```

**Solutions**:

- **If IP not whitelisted**: Update Terraform and reapply
  ```bash
  cd infrastructure/ansible-stack
  # Edit terraform.tfvars to add your IP
  terraform apply
  ```

- **If wrong SSH key**: Verify SSH key path in inventory
  ```bash
  cat configuration/ansible/inventory/terraform_inventory.yaml | grep ansible_ssh_private_key_file
  ```

- **If SSH agent issue**: Add key to agent
  ```bash
  eval $(ssh-agent)
  ssh-add ~/.ssh/your-key.pem
  ```

### 4. Database Connection Errors

**Symptoms**: Management service logs show:
```
level=error msg="failed to connect to database" error="dial tcp: connection refused"
```

**Cause**: Database not accessible, incorrect credentials, or firewall blocking.

**Diagnosis**:

1. **Test database connectivity**:
   ```bash
   ssh management-node
   psql "host=db.example.com port=5432 dbname=netbird user=netbird password=xxx sslmode=require"
   ```
   
   **Expected output**:
   ```
   psql (14.10)
   SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256)
   Type "help" for help.
   netbird=>
   ```

2. **Check database configuration**:
   ```bash
   cat /opt/netbird/management.json | jq '.Datastore'
   ```
   
   **Expected**:
   ```json
   {
     "Engine": "postgres",
     "postgreSQL": {
       "Host": "db.example.com",
       "Port": 5432,
       "Database": "netbird"
     }
   }
   ```

3. **Verify database security group**:
   ```bash
   # Database must allow management node IP on port 5432
   ```

**Solutions**:

- **If credentials wrong**: Update terraform.tfvars and redeploy
  ```bash
  cd infrastructure/ansible-stack
  # Update database credentials
  terraform apply
  cd ../../configuration/ansible
  ansible-playbook -i inventory/terraform_inventory.yaml playbooks/site.yml
  ```

- **If database not created**: Run migration script
  ```bash
  ssh management-node
  sudo /opt/netbird/scripts/init-db.sh
  ```

### 5. Let's Encrypt Certificate Issues

**Symptoms**: HTTPS not working, browser shows "Not Secure" warning.

**Cause**: Let's Encrypt rate limit, DNS not propagated, or ports blocked.

**Diagnosis**:

1. **Check Caddy logs for ACME errors**:
   ```bash
   ssh reverse-proxy
   docker logs caddy 2>&1 | grep -i "acme\|certificate\|tls"
   ```
   
   **Common errors**:
   ```
   obtaining certificate: acme: error: 429 :: too many certificates
   obtaining certificate: timeout during connect
   ```

2. **Verify DNS resolution**:
   ```bash
   dig netbird.yourdomain.com +short
   # Should return reverse-proxy public IP
   ```

3. **Test port accessibility**:
   ```bash
   # From external network
   nc -vz netbird.yourdomain.com 80
   nc -vz netbird.yourdomain.com 443
   ```
   
   **Expected**:
   ```
   Connection to netbird.yourdomain.com 80 port [tcp/http] succeeded!
   Connection to netbird.yourdomain.com 443 port [tcp/https] succeeded!
   ```

**Solutions**:

- **If rate limited**: Wait 1 week or use staging environment for testing
  ```bash
  # Edit Caddyfile to use staging ACME
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
  ```

- **If DNS not propagated**: Wait for DNS propagation (up to 48 hours)
  ```bash
  # Check propagation status
  dig netbird.yourdomain.com @8.8.8.8
  dig netbird.yourdomain.com @1.1.1.1
  ```

- **If ports blocked**: Ensure security group allows 80/443 from 0.0.0.0/0

## Collecting Diagnostics

### Complete Diagnostic Collection Script

Run this comprehensive diagnostic collection on each node type:

**Management Node**:
```bash
#!/bin/bash
# Create diagnostics directory
mkdir -p netbird-diagnostics
cd netbird-diagnostics

# Service logs
docker-compose -f /opt/netbird/docker-compose.yml logs --tail=500 > docker-logs.txt

# Container status
docker ps -a > docker-status.txt

# System info
uname -a > system-info.txt
df -h > disk-usage.txt
free -h > memory-usage.txt

# Network configuration
ip addr show > network-interfaces.txt
ip route show > routing-table.txt
ss -tulpn > listening-ports.txt

# Firewall rules
sudo ufw status verbose > firewall-status.txt

# Configuration files (sanitized)
cat /opt/netbird/management.json | jq 'del(.Datastore.postgreSQL.Password)' > management-config.txt
cat /opt/netbird/docker-compose.yml > docker-compose.txt

# Create tarball
cd ..
tar -czf netbird-diagnostics-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz netbird-diagnostics/

echo "Diagnostics collected: netbird-diagnostics-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"
```

**Expected output**:
```
Diagnostics collected: netbird-diagnostics-management-node-20260216-142030.tar.gz
```

**Reverse Proxy Node**:
```bash
#!/bin/bash
mkdir -p caddy-diagnostics
cd caddy-diagnostics

# Caddy logs
docker logs caddy --tail=500 > caddy-logs.txt 2>&1

# Caddy configuration
cat /etc/caddy/Caddyfile > Caddyfile.txt

# SSL/TLS certificates
ls -lh /var/lib/caddy/.local/share/caddy/certificates/ > certificates.txt

# Network info
ip addr show > network-interfaces.txt
ss -tulpn > listening-ports.txt
sudo ufw status verbose > firewall-status.txt

# Create tarball
cd ..
tar -czf caddy-diagnostics-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz caddy-diagnostics/

echo "Diagnostics collected: caddy-diagnostics-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"
```

### Quick Health Check

Run this one-liner to verify all components:

```bash
# From your local machine
ansible -i configuration/ansible/inventory/terraform_inventory.yaml all -m shell -a "systemctl is-active docker && docker ps --format '{{.Names}}: {{.Status}}'"
```

**Expected output**:
```
management-node | SUCCESS | rc=0 >>
active
netbird-management: Up 2 hours (healthy)
netbird-signal: Up 2 hours (healthy)

reverse-proxy | SUCCESS | rc=0 >>
active
caddy: Up 2 hours (healthy)
```

## Performance Issues

### High CPU Usage

**Symptoms**: Servers unresponsive, slow API responses.

**Diagnosis**:
```bash
ssh management-node
top -b -n 1 | head -20
docker stats --no-stream
```

**Expected output** (healthy):
```
CONTAINER           CPU %    MEM USAGE / LIMIT
netbird-management  5.23%    245MiB / 2GiB
netbird-signal      2.15%    128MiB / 2GiB
```

**Solutions**:

- If CPU > 80% sustained: Consider scaling horizontally (add more management nodes)
- If memory high: Check for memory leaks in logs, restart services
- If database slow: Optimize queries, add indexes, enable connection pooling

### Disk Space Issues

**Symptoms**: Services crashing, logs showing "no space left on device".

**Diagnosis**:
```bash
df -h
du -sh /var/lib/docker/* | sort -h
docker system df
```

**Solutions**:
```bash
# Clean old Docker images and containers
docker system prune -a --volumes -f

# Rotate logs
sudo journalctl --vacuum-time=7d

# If SQLite database large
ls -lh /var/lib/netbird/store.db
# Consider migrating to PostgreSQL
```

## Getting Help

If issues persist after troubleshooting:

1. **Collect diagnostics** using scripts above
2. **Check NetBird GitHub Issues**: https://github.com/netbirdio/netbird/issues
3. **NetBird Slack Community**: https://netbird.io/slack
4. **Review deployment logs** in CI/CD if using automation

## Related Documentation

- [Upgrade Guide](./upgrade-guide.md) - Upgrading NetBird versions
- [Database Migration](./database-migration.md) - Migrating database backends
- [Monitoring & Alerting](../../../docs/operations/monitoring-alerting.md) - Proactive monitoring
