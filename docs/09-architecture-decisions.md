# 09 - Architecture Decisions

This document records the key architectural decisions (ADRs) for this project.

## ADR-001: Separation of Infrastructure vs Configuration
*   **Decision**: Use Terraform for immutable infrastructure (VMs, DBs) and Ansible for mutable configuration (Software, Config files).
*   **Reason**: Terraform is superior for state management of cloud resources. Ansible is superior for procedural configuration and rolling updates of software.

## ADR-002: Reverse Proxy with Private Backends
*   **Decision**: Use a public-facing Caddy Reverse Proxy and hide Management nodes in a private network/subnet/security group.
*   **Reason**: Security Deep-in-Depth. Prevents direct attack surface on the application logic. Caddy was chosen over Nginx for its automatic HTTPS (ACME) handling and ease of config (`Caddyfile` vs verbose Nginx conf).

## ADR-003: Discovery of Default VPC with Security Groups
*   **Decision**: Instead of creating a custom VPC, we discover the existing "Default" VPC and apply strict ISO-Layer-4 locking via Security Groups.
*   **Reason**:
    1.  **Simplicity**: Reduces Terraform complexity (no Subnet/RouteTable/IGW management).
    2.  **Compatibility**: Works in environments where users cannot create new VPCs.
    3.  **Security Parity**: Security Groups provide equivalent isolation to Private Subnets when configured correctly (Inbound Whitelisting).

## ADR-004: Private IP Binding
*   **Decision**: Bin NetBird services `ansible_default_ipv4.address` instead of `0.0.0.0`.
*   **Reason**: Prevents accidental exposure. Even if the Firewall is flushed (`ufw disable`), the application itself will refuse connections from external interfaces/IPs (if bound strictly).

## Next Steps
Proceed to [10-glossary.md](./10-glossary.md).
