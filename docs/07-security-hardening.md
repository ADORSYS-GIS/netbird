# 07 - Security Hardening

This document details the security measures implemented in this project, focusing on the "Secure by Default" architecture.

## 1. Network Segmentation (Defense in Depth)

We utilize a multi-layered approach to network security.

### Layer 1: Cloud Security Groups (Terraform)
*   **Reverse Proxy Group**:
    *   **Inbound**: 80 (HTTP), 443 (HTTPS), 3478 (STUN/UDP), 22 (SSH - Restricted to Admin CIDR).
    *   **Outbound**: All traffic (to communicate with Management/DB).
*   **Management Group**:
    *   **Inbound**:
        *   Port 80/8080/10000: **ONLY** from Reverse Proxy Group.
        *   Port 22 (SSH): **ONLY** from Admin CIDR.
    *   **Outbound**: To PostgreSQL and Internet (for updates).
*   **Database Group**:
    *   **Inbound**: Port 5432: **ONLY** from Management Group.

### Layer 2: Host Firewall (UFW)
Configured via `configuration/roles/common/tasks/firewall.yml`.
*   **Reverse Proxy**: Explicitly allows 80, 443, 3478.
*   **Management**: Explicitly allows traffic from the **Private IP of the Reverse Proxy**.

### Layer 3: Application Binding
*   NetBird services bind to `{{ ansible_default_ipv4.address }}` (Private IP).
*   They strictly **DO NOT** listen on `0.0.0.0`. This prevents accidental exposure if SGs/UFW fail.

## 2. Secrets Management

*   **Infrastructure Secrets**: Passed via `terraform.tfvars` (sensitive variables marked in Terraform).
*   **Application Secrets**:
    *   `settings.json` generated on the fly by Ansible from inventory variables.
    *   Recommended: Use **Ansible Vault** to encrypt `group_vars/*.yml`.

## 3. SSL/TLS
*   **Termination**: Handled by Caddy at the edge.
*   **Certificates**: Automated Let's Encrypt (ACME).
*   **Internal Traffic**: HTTP (Plaintext) inside the VPC, but isolated by Private IP.

## Compliance
*   **CIS Benchmark**: Ubuntu 22.04 LTS (Base Image) is generally compliant; further hardening can be applied via Ansible (e.g., disable root SSH, enforce password policies).

## Next Steps
Proceed to [08-monitoring-alerting.md](./08-monitoring-alerting.md).
