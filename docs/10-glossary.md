# 10 - Glossary

Definitions of terms used in this documentation.

*   **Management Node**: Validates peers, distributes network maps (routes/peers/ACLs).
*   **Signal Service**: Facilitates initial p2p connection negotiation (NAT traversal).
*   **Relay Service**: Relays traffic when p2p connection cannot be established (TURN).
*   **Reverse Proxy**: The entry point (Caddy) that handles TLS and routes traffic to internal services.
*   **Inventory**: The list of servers (IPs, Roles, Metadata) used by Ansible.
*   **Playbook**: Ansible YAML file describing the desired state of the system.
*   **Terraform State**: File tracking the mapping between real-world resources and your configuration.
*   **UFW**: Uncomplicated Firewall (Linux host firewall).
*   **Security Group**: Cloud-level firewall (AWS/Azure/GCP).
