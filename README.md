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
- Prometheus for metrics
- Loki for logs
- Grafana for dashboards

High‑level operator documentation for deploying and managing the monitoring stack is available:

-   **Docker Compose Deployment:** [`docs/Monitoring-NetBird-Observability-Docker-Compose.md`](docs/Monitoring-NetBird-Observability-Docker-Compose.md)
-   **Kubernetes Deployment (Helm):** [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md)

Explore the `docs/` directory for additional documentation, including architecture overviews and deployment guides.

## Contributing

We welcome contributions to the NetBird project!

## Additional documentation

All documentation lives under the `docs/` tree. Start with:

- [`docs/Monitoring-NetBird-Observability-Docker-Compose.md`](docs/Monitoring-NetBird-Observability-Docker-Compose.md)
- [`docs/Monitoring-NetBird-Observability-Kubernetes.md`](docs/Monitoring-NetBird-Observability-Kubernetes.md)

