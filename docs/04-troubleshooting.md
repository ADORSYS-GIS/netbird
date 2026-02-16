# 04 - Troubleshooting Guide

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
**Cause**: Caddy cannot talk to the backend Management service.
**Diagnosis**:
1.  SSH into `reverse-proxy`.
2.  Check Caddy logs: `docker logs caddy`
3.  Ping management node private IP: `ping 10.x.x.x`
4.  Check UFW on Management node: `ssh management-node "sudo ufw status"`

**Solution**: Ensure UFW on Management node allows traffic from Reverse Proxy IP on port 8080.

### 2. Agents cannot verify connection
**Symptoms**: `netbird up` fails with connection timeout.
**Cause**: Signal service is unreachable or GRPC blocked.
**Diagnosis**:
1.  Check Caddy configuration for `/signalexchange`.
2.  Verify Port 10000 on Management node is bound to Private IP.
3.  Check Terraform Security Groups.

### 3. Deploy Playbook Fails on SSH
**Symptoms**: Ansible cannot connect to hosts.
**Cause**: SSH key issue or Security Group blocking SSH.
**Solution**:
*   Verify `admin_cidr_blocks` in Terraform includes your IP.
*   Use `-vvv` with ansible-playbook to debug SSH connection.

## Collecting Diagnostics

Running the following command on any node will gather logs for support:

```bash
# On Management Node
docker-compose -f /opt/netbird/docker-compose.yml logs > netbird_logs.txt
sudo ufw status > firewall_status.txt
ip addr > network_info.txt
```

## Next Steps
Proceed to [05-upgrade-guide.md](./05-upgrade-guide.md).
