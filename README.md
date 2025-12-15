# NetBird Deployment

NetBird is an open-source VPN solution that allows you to create secure private networks for your teams and infrastructure. It uses WireGuard® to create a secure overlay network, enabling direct, peer-to-peer connections between your devices, regardless of their physical location.

## Key Features

- **Secure Private Networks**: Build secure, encrypted networks for your devices and services.

- **Peer-to-Peer Connectivity**: Direct connections between devices, reducing latency and improving performance.

- **Identity-Based Access Control**: Integrate with your existing Identity Provider (IdP) for user authentication and authorization.

- **Simple Configuration**: Easy to set up and manage, even for complex network topologies.

- **Cross-Platform Support**: Clients available for Linux, Windows, macOS, iOS, and Android.

## Deployment Options

NetBird can be deployed in various ways, depending on your needs:

- **Self-Hosted**: Deploy NetBird on your own infrastructure for complete control.
- **Cloud-Managed**: Utilize managed NetBird services for simplified operations.

This repository includes an Ansible automation suite for self-hosting NetBird with Caddy as a reverse proxy, providing automated SSL/TLS and simplified service management.

## Getting Started with Ansible Automation

For detailed instructions on deploying NetBird using our Ansible automation with Caddy, please refer to the dedicated README:

- [`ansible-automation/README.md`](ansible-automation/README.md)

This automation covers:

- System preparation (Docker, UFW)
- NetBird service deployment
- Caddy reverse proxy configuration with automatic SSL
- Templated configuration files for easy customization
- Integration placeholders for Keycloak (OIDC)

## Documentation

Explore the `docs/` directory for additional documentation, including architecture overviews and deployment guides.

## Contributing

We welcome contributions to the NetBird project!
