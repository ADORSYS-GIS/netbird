# Requirements: HAProxy and Autocert Management Validation

## 1. Overview

Ensure the HAProxy role deploys correctly with automatic certificate management via ACME.sh, providing reliable TLS termination and load balancing configuration for NetBird infrastructure. This validation focuses on HAProxy deployment and certificate automation, with backend routing functionality to be validated after backend services are deployed.

## 2. User Stories

### 2.1 As a DevOps Engineer
I want HAProxy to deploy successfully with valid TLS certificates so that the NetBird infrastructure is accessible over HTTPS without manual certificate management.

### 2.2 As a System Administrator
I want automatic certificate renewal to work reliably so that services remain available without certificate expiration incidents.

### 2.3 As a Security Engineer
I want to verify that TLS configuration follows best practices so that the infrastructure is secure against known vulnerabilities.

### 2.4 As a Platform Engineer
I want HAProxy to be configured with proper backend routing rules so that traffic will be distributed correctly once backend services are deployed.

## 3. Acceptance Criteria

### 3.1 HAProxy Deployment
- [ ] HAProxy container starts successfully
- [ ] HAProxy configuration is syntactically valid
- [ ] HAProxy listens on ports 80, 443, and 8404
- [ ] HAProxy passes health checks within 30 seconds
- [ ] HAProxy stats dashboard is accessible
- [ ] HAProxy configuration includes all backend definitions (management, relay, signal, dashboard, API)

### 3.2 ACME.sh Certificate Management
- [ ] ACME.sh container starts successfully
- [ ] ACME.sh can issue certificates for the primary domain
- [ ] ACME.sh can issue wildcard certificates
- [ ] Certificates are installed in the correct location (/etc/haproxy/certs/)
- [ ] Certificate files have correct permissions (644)
- [ ] Certificate renewal daemon runs continuously
- [ ] Renewal checks execute daily

### 3.3 TLS Configuration
- [ ] TLS 1.2 is the minimum supported version
- [ ] Strong cipher suites are configured
- [ ] Certificate chain is complete and valid
- [ ] HTTPS connections succeed with valid certificates
- [ ] HTTP requests redirect to HTTPS (301)
- [ ] Self-signed fallback certificate is created if ACME fails

### 3.4 Backend Configuration and Routing
- [ ] Management gRPC backend is configured (HTTP/2)
- [ ] Signal gRPC backend is configured (HTTP/2)
- [ ] WebSocket backends are configured
- [ ] Relay backend is configured
- [ ] API backend is configured
- [ ] Dashboard backend is configured
- [ ] ACME challenge requests route to acme-sh container
- [ ] Backend health checks are configured properly
- [ ] Sticky sessions are configured for appropriate backends
- [ ] HAProxy handles unavailable backends gracefully (shows as down in stats)
- [ ] Routing rules are syntactically correct and non-conflicting

### 3.5 High Availability (Keepalived)
- [ ] Keepalived installs successfully
- [ ] Keepalived configuration is valid
- [ ] Virtual IP is assigned to master node
- [ ] Health check script monitors HAProxy status
- [ ] Failover occurs when master fails
- [ ] Notification scripts execute on state changes

### 3.6 Monitoring and Observability
- [ ] HAProxy logs are accessible
- [ ] ACME.sh logs are accessible
- [ ] Certificate expiry can be checked
- [ ] Stats dashboard shows backend status
- [ ] Container health status is accurate

### 3.7 Error Handling
- [ ] Configuration validation catches syntax errors
- [ ] Self-signed certificate fallback works
- [ ] ACME failures are logged clearly
- [ ] Container restart policies work correctly
- [ ] Firewall rules are configured properly

## 4. Constraints

### 4.1 Technical Constraints
- Must use HAProxy 3.2 or later
- Must use ACME.sh for Let's Encrypt integration
- Must support HTTP-01 challenge method
- Must work with Docker Compose
- Must be idempotent (Ansible best practice)

### 4.2 Security Constraints
- No self-signed certificates in production (except as fallback)
- TLS 1.2 minimum
- Strong cipher suites only
- Certificate private keys must be protected
- Stats dashboard should require authentication

### 4.3 Operational Constraints
- Zero-downtime certificate renewal
- Graceful configuration reloads
- Health checks must not cause false positives
- Logs must be rotated to prevent disk fill

## 5. Dependencies

### 5.1 External Dependencies
- Docker and Docker Compose
- Let's Encrypt ACME service availability
- DNS records pointing to HAProxy nodes
- Firewall allowing ports 80, 443, 8404

### 5.2 Internal Dependencies
- NetBird management nodes defined in inventory (may not be deployed yet)
- NetBird relay nodes defined in inventory (may not be deployed yet)
- Private network connectivity between HAProxy and backends (when deployed)
- Ansible inventory with correct host groups

## 6. Success Metrics

### 6.1 Deployment Success
- 100% successful HAProxy deployments
- 100% successful ACME.sh deployments
- Certificate issuance within 5 minutes
- Zero manual interventions required
- Role completes without errors

### 6.2 Reliability
- 99.9% uptime for HAProxy service
- 100% successful certificate renewals
- Zero certificate expiration incidents
- Failover time < 10 seconds (with Keepalived)

### 6.3 Performance
- TLS handshake time < 100ms
- Backend health check interval: 5 seconds
- Stats dashboard response time < 1 second

## 7. Out of Scope

- Backend service deployment (management, relay nodes)
- End-to-end routing validation with live traffic (tested after backend deployment)
- Custom ACME providers (only Let's Encrypt)
- DNS-01 challenge method
- Certificate management for non-NetBird domains
- WAF (Web Application Firewall) features
- DDoS protection beyond basic rate limiting
- Multi-region load balancing

## 8. Testing Requirements

### 8.1 Unit Tests
- Ansible task syntax validation
- Jinja2 template rendering validation
- Variable default value tests

### 8.2 Integration Tests
- Full deployment test in test environment
- Certificate issuance test
- Certificate renewal test
- Failover test (Keepalived)
- Backend configuration validation (without live backends)

### 8.3 Property-Based Tests
- Configuration always validates successfully
- Certificates are always readable by HAProxy
- Health checks always reflect actual service status
- Routing rules never conflict

### 8.4 Manual Tests
- Browser HTTPS connection test
- Certificate chain validation
- Stats dashboard access
- Log file inspection
- Firewall rule verification

## 9. Documentation Requirements

- [ ] Update HAProxy role README with troubleshooting steps
- [ ] Document certificate renewal process
- [ ] Document failover testing procedure
- [ ] Create runbook for common issues
- [ ] Add monitoring and alerting recommendations

## 10. Risks and Mitigations

### 10.1 Risk: Let's Encrypt Rate Limits
**Mitigation**: Use staging environment for testing, implement exponential backoff

### 10.2 Risk: Certificate Renewal Failure
**Mitigation**: Monitor certificate expiry, alert 7 days before expiration, maintain fallback certificate

### 10.3 Risk: HAProxy Configuration Error
**Mitigation**: Validate configuration before applying, test in staging first

### 10.4 Risk: Network Connectivity Issues
**Mitigation**: Implement retry logic, health checks, and failover

### 10.5 Risk: Docker Container Failures
**Mitigation**: Restart policies, health checks, monitoring alerts


