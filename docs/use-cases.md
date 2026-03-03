# NetBird Use Cases

Discover the primary use cases for NetBird, from creating a simple point-to-site VPN to establishing a complex mesh network for your entire infrastructure.

## Overview

NetBird is a WireGuard-based mesh VPN that enables secure connectivity between devices, servers, and networks using zero-trust principles. This guide covers common deployment scenarios.

## Use Case 1: Point-to-Site VPN (Remote Access)

Connect remote users securely to your infrastructure without exposing services to the internet.

**Scenario:**
- Remote employees need access to internal services
- No public IPs or firewall rules required
- Zero-trust access control with SSO and MFA

**Architecture:**
```
[Remote Devices] ←→ NetBird Mesh ←→ [Internal Services]
                                      - Databases
                                      - APIs
                                      - Admin Panels
```

**Benefits:**
- No VPN client configuration needed
- Automatic peer discovery and connection
- Works behind NAT/firewalls
- Fine-grained access control via groups and policies
- End-to-end encryption

**Setup Steps:**
1. Deploy NetBird infrastructure ([deployment guide](../infrastructure/ansible-stack/README.md))
2. Install NetBird client on user devices
3. Create setup keys in NetBird dashboard
4. Configure access control groups and policies
5. Users connect automatically via SSO

## Use Case 2: Site-to-Site VPN (Network Routes)

Connect multiple office locations, data centers, or cloud VPCs without installing NetBird on every device.

**Scenario:**
- Multiple office locations need to communicate
- Cloud VPCs need to access on-premise systems
- Hybrid cloud connectivity across AWS, GCP, Azure

**Architecture:**
```
[Office A Network] ←→ [Routing Peer A] ←→ NetBird Mesh ←→ [Routing Peer B] ←→ [Office B Network]
   10.0.1.0/24                                                                    10.0.2.0/24
```

**Key Concepts:**
- **Routing Peer**: NetBird device that forwards traffic between NetBird mesh and private networks
- **Network Routes**: Define which networks are accessible through routing peers
- **Masquerade**: NAT mode (default) - simplifies setup, hides source IPs
- **High Availability**: Multiple routing peers for redundancy

**Setup Steps:**

1. **Install NetBird on Routing Peers:**
   ```bash
   # On each routing peer (Linux/Windows/macOS)
   curl -fsSL https://pkgs.netbird.io/install.sh | sh
   netbird up --setup-key <your-setup-key>
   ```

2. **Enable IP Forwarding:**
   ```bash
   # Linux
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   sysctl -p
   
   # Verify
   sysctl net.ipv4.ip_forward
   ```

3. **Create Network Route in NetBird Dashboard:**
   - Navigate to **Network Routes** → **Add Route**
   - **Network Identifier**: `office-a-network`
   - **Network Range**: `10.0.1.0/24`
   - **Routing Peer**: Select your routing peer
   - **Distribution Groups**: Select groups that should access this network
   - **Masquerade**: Enabled (recommended)
   - Click **Add Route**

4. **Configure High Availability (Optional):**
   - Add multiple routing peers for the same network
   - Use **Peer Groups** for automatic failover
   - Set **Metric** values (lower = higher priority)

**Testing:**
```bash
# From NetBird client
ping 10.0.1.10  # Device in Office A network
ssh user@10.0.1.10  # SSH to device in Office A
```

## Use Case 3: Secure Application Access

Provide secure, zero-trust access to internal applications without exposing them to the internet.

**Scenario:**
- Internal web applications (admin panels, monitoring tools)
- Database access for developers
- SSH access to servers
- No bastion hosts or VPN concentrators needed

**Architecture:**
```
[User Device] ←→ NetBird Mesh ←→ [Application Server]
                                  - No public IP
                                  - No firewall rules
                                  - Zero-trust access
```

**Access Control Example:**

1. **Create Groups:**
   - `developers` - Development team
   - `database-servers` - PostgreSQL/MySQL servers
   - `web-servers` - Internal web applications

2. **Create Access Policies:**
   ```
   Policy: Database Access
   Source: developers
   Destination: database-servers
   Protocol: TCP
   Ports: 5432 (PostgreSQL), 3306 (MySQL)
   Action: Allow
   
   Policy: Web Access
   Source: developers
   Destination: web-servers
   Protocol: TCP
   Ports: 80, 443
   Action: Allow
   
   Policy: SSH Access
   Source: developers
   Destination: database-servers, web-servers
   Protocol: TCP
   Ports: 22
   Action: Allow
   ```

3. **Assign Peers to Groups:**
   - Add application servers to appropriate groups
   - Add user devices to `developers` group

**Benefits:**
- No firewall configuration needed
- Granular access control per protocol/port
- Complete audit trail
- MFA enforcement via SSO
- Automatic encryption

See [Secure Application Access Tutorial](secure-access.md) for detailed step-by-step guide.

## Use Case 4: AWS VPC Integration

Connect NetBird mesh network with AWS VPC resources securely.

**Scenario:**
- Access EC2 instances on private subnets
- Connect to RDS databases without public endpoints
- Hybrid cloud connectivity
- No VPN gateway or Direct Connect needed

**Architecture:**
```
[NetBird Clients] ←→ NetBird Mesh ←→ [EC2 Routing Peer] ←→ [AWS VPC]
                                                              - Private EC2
                                                              - RDS
                                                              - ElastiCache
```

**Setup Steps:**

1. **Launch EC2 Routing Peer:**
   ```bash
   # Launch EC2 instance in public subnet
   # Install NetBird
   curl -fsSL https://pkgs.netbird.io/install.sh | sh
   netbird up --setup-key <your-setup-key>
   ```

2. **Disable Source/Destination Checks:**
   - AWS Console → EC2 → Select Instance
   - Actions → Networking → Change Source/Dest Check
   - **Disable** (required for routing)

3. **Enable IP Forwarding:**
   ```bash
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   sysctl -p
   ```

4. **Configure VPC Route Table:**
   - Navigate to VPC → Route Tables
   - Select route table for private subnets
   - Add route:
     ```
     Destination: 100.64.0.0/10 (NetBird network)
     Target: eni-xxx (Routing Peer ENI)
     ```

5. **Configure Security Groups:**
   ```
   Inbound Rules for Private Resources:
   - Type: All Traffic
   - Source: 100.64.0.0/10 (NetBird network)
   - Description: NetBird mesh access
   ```

6. **Create Network Route in NetBird:**
   - **Network Identifier**: `aws-vpc-prod`
   - **Network Range**: `10.0.0.0/16` (your VPC CIDR)
   - **Routing Peer**: Select EC2 routing peer
   - **Distribution Groups**: Select authorized groups
   - **Masquerade**: Enabled

**Testing:**
```bash
# From NetBird client
ping 10.0.1.10  # Private EC2 instance
ssh ec2-user@10.0.1.10  # SSH to private EC2
psql -h db.internal.vpc -U admin  # Connect to private RDS
```

See [AWS VPC Integration Guide](aws-vpc-integration.md) for detailed instructions with screenshots.

## Use Case 5: Multi-Cloud Connectivity

Connect workloads across AWS, GCP, Azure, or on-premise without exposing traffic to the public internet.

**Scenario:**
- Workloads in different cloud providers need to communicate
- Database migration between clouds
- Hybrid cloud applications
- Disaster recovery across regions

**Architecture:**
```
[AWS VPC] ←→ [Routing Peer A] ←→ NetBird Mesh ←→ [Routing Peer B] ←→ [GCP VPC]
                                      ↕
                              [Routing Peer C] ←→ [Azure VNet]
```

**Setup:**
1. Deploy routing peers in each cloud environment
2. Configure network routes for each VPC/VNet
3. Set up high availability with multiple routing peers
4. Configure access policies between clouds

**Benefits:**
- No cloud-specific VPN gateways needed
- Simplified multi-cloud networking
- Consistent security policies
- Cost-effective compared to cloud VPN services

## Use Case 6: Kubernetes Cluster Access

Secure access to Kubernetes clusters without exposing the API server.

**Scenario:**
- Developers need kubectl access
- CI/CD pipelines need cluster access
- No public API server endpoint
- No bastion hosts

**Setup:**
1. Install NetBird on a node with cluster access
2. Configure kubeconfig to use private IP
3. Developers connect via NetBird
4. Access cluster securely with kubectl

**Benefits:**
- No bastion hosts needed
- Audit trail of all access
- Fine-grained RBAC via NetBird groups
- Works with any Kubernetes distribution

## Best Practices

### Network Design
- Use separate groups for different access levels (dev, staging, prod)
- Implement least-privilege access policies
- Use routing peers for site-to-site connectivity
- Enable high availability for critical routes

### Security
- Enable MFA in your identity provider (Keycloak/Zitadel)
- Regularly rotate setup keys
- Monitor activity logs for suspicious access
- Use protocol and port restrictions in policies
- Implement posture checks for device compliance

### Performance
- Deploy relay servers in strategic locations for better connectivity
- Use routing peers for high-bandwidth connections
- Monitor peer connection quality
- Use masquerade mode unless source IP visibility is required

### Operations
- Automate peer deployment with Ansible
- Use tags for dynamic grouping
- Implement monitoring and alerting
- Regular backup of NetBird configuration
- Document network routes and access policies

## Zero Trust Principles

NetBird implements zero trust networking:

1. **Verify Explicitly**: Every connection is authenticated and authorized
2. **Least Privilege**: Access granted only to specific resources, not entire networks
3. **Assume Breach**: End-to-end encryption for all traffic

**Key Features:**
- Access Control Policies - Define who can access what resources
- Posture Checks - Verify device compliance before granting access
- Activity Logging - Audit all access events
- MFA Integration - Enforce multi-factor authentication
- SSO - Integrate with identity providers

## Next Steps

- [Secure Application Access Tutorial](secure-access.md)
- [AWS VPC Integration Guide](aws-vpc-integration.md)
- [Deployment Guide](../infrastructure/ansible-stack/README.md)
- [Configuration Reference](configuration.md)
- [Official NetBird Documentation](https://docs.netbird.io/)
