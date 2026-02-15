# NetBird HA Architecture

This directory contains architectural diagrams and decision records (ADRs) regarding the High Availability setup of NetBird.

## Diagrams
- `ha-overview.png`: High-level overview of components.
- `data-flow.png`: Data flow between Agents, Signal, Management, and Relay services.

## Components
- **Management Service**: Stateless, horizontally scalable.
- **Signal Service**: Stateless, horizontally scalable.
- **Relay Service**: Distributed TURN servers.
- **Data Store**: HA PostgreSQL cluster.
