
# Self-Hosted Deployment of NetBird with Keycloak and Caddy

## Overview

This document describes a self-hosted architecture in which NetBird is deployed for overlay networking, Keycloak serves as the identity and access management (IAM) provider, and Caddy acts as the reverse proxy and TLS termination component. The environment uses Ubuntu 24.05 for both the NetBird/Caddy host and the Keycloak host.

* NetBird domain: `your-netbird-domain.example.com`
* Keycloak domain: `your-keycloak-domain.example.com`
* External access via TCP 443 (with TLS termination by Caddy)
* Internal HTTP proxying by Caddy to NetBird services
* Keycloak accessible publicly via its domain

## Architecture & Topology

* NetBird server and Caddy run together on a single Ubuntu 24.05 machine.
* Keycloak runs on a separate machine, publicly accessible via its domain.
* Caddy receives client connections on ports 80 and 443, performs certificate issuance, then proxies internally to NetBird backend services.
* NetBird’s components include: Dashboard/Management API, Signal Service, Relay/TURN service.
* Keycloak acts as the OIDC provider for user authentication and for the NetBird management API to query users.
* The reverse proxy configuration must support HTTP, gRPC, WebSocket upgrade, and in some cases UDP (for TURN/relay) as described in the official NetBird docs.

## Pre-requisites

* Ubuntu 24.05 (or equivalent) with Docker and Docker Compose installed.
* A DNS A record for `your-netbird-domain.example.com` pointing to the public IP of the NetBird/Caddy host.
* A DNS A record for `your-keycloak-domain.example.com` pointing to the Keycloak host.
* Ports open on the NetBird host: TCP 80 and 443 (for Caddy). Additionally, for full functionality: TCP 33073, TCP 10000, TCP 33080; UDP 3478 and UDP 49152-65535 (for relay) as recommended.
* A running Keycloak instance with a realm and clients configured ahead of time.
* Understanding of reverse proxy configuration, including WebSocket and gRPC forwarding.

## Configuration Steps

### 1. NetBird Setup

1. On the NetBird host, copy `setup.env.example` to `setup.env`. Populate with values such as:

   ```env
   NETBIRD_DOMAIN=your-netbird-domain.example.com  
   NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://your-keycloak-domain.example.com/realms/netbird/.well-known/openid-configuration  
   NETBIRD_AUTH_AUDIENCE=netbird-client  
   NETBIRD_AUTH_CLIENT_ID=netbird-client  
   NETBIRD_AUTH_SUPPORTED_SCOPES="openid profile email offline_access api"  
   NETBIRD_LETSENCRYPT_EMAIL=  
   NETBIRD_DISABLE_LETSENCRYPT=true  
   ```

2. Add management-API/IDP variables (required when using Keycloak for NetBird management API):

   ```bash
   NETBIRD_MGMT_IDP="keycloak"
   NETBIRD_IDP_MGMT_CLIENT_ID="netbird-backend"
   NETBIRD_IDP_MGMT_CLIENT_SECRET="<CLIENT_SECRET_HERE>"
   NETBIRD_IDP_MGMT_EXTRA_ADMIN_ENDPOINT="https://your-keycloak-domain.example.com/admin/realms/netbird"
   ```

3. Run the configuration script:

   ```bash
   ./configure.sh
   ```

4. Review the generated `docker-compose.yml`, `management.json`, and `turnserver.conf`. Insert the Caddy service, ensure internal ports and service names align, and verify the TURN/relay secret matches environment settings.
5. Start the stack:

   ```bash
   cd artifacts  
   docker compose up -d
   ```

   Confirm all containers are running and no critical errors appear.

### 2. Keycloak Integration

1. On the Keycloak server (realm: `netbird` assumed):

   * Create client **netbird-client** (OIDC interactive): Redirect URI `https://your-netbird-domain.example.com/*`, scopes: `openid`, `profile`, `email`, `offline_access`, `api`.
   * Create client **netbird-backend** (service/client credentials): no redirect URI required; copy the client secret. Assign role `view-users` (or equivalent) so NetBird backend can query user list.
2. Confirm Keycloak’s issuer, audience and OIDC configuration endpoint match values in NetBird’s `setup.env`.

### 3. Caddy Reverse Proxy Setup

Use the following Caddyfile snippet (with placeholders for domain, etc):

```caddyfile
{
    acme_ca https://acme.zerossl.com/v2/DV90
    email admin@example.com
}

your-netbird-domain.example.com {

    header {
        Strict-Transport-Security max-age=31536000;
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
    }

    reverse_proxy /management.ManagementService/* {
        to management:80
        transport http {
            versions h2c
        }
    }

    reverse_proxy /signalexchange.SignalExchange/* {
        to signal:80
        transport http {
            versions h2c
        }
    }

    reverse_proxy /ws-proxy/signal* {
        to signal:80
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
        header_up Upgrade {>Upgrade}
        header_up Connection {>Connection}
    }

    reverse_proxy /ws-proxy/management* {
        to management:80
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
    }

    reverse_proxy /relay* {
        to relay:33080
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
        header_up Upgrade {>Upgrade}
        header_up Connection {>Connection}
    }

    reverse_proxy /api/* {
        to management:80
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
    }

    reverse_proxy /* {
        to dashboard:80
        header_up Host {host}
        header_up X-Real-IP {remote_ip}
        header_up X-Forwarded-For {remote_ip}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

## Key Configuration Values

```env
NETBIRD_DOMAIN=your-netbird-domain.example.com  
NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT=https://your-keycloak-domain.example.com/realms/netbird/.well-known/openid-configuration  
NETBIRD_AUTH_AUDIENCE=netbird-client  
NETBIRD_AUTH_CLIENT_ID=netbird-client  
NETBIRD_AUTH_SUPPORTED_SCOPES="openid profile email offline_access api"  
NETBIRD_LETSENCRYPT_EMAIL=  
NETBIRD_DISABLE_LETSENCRYPT=true  

NETBIRD_MGMT_IDP="keycloak"
NETBIRD_IDP_MGMT_CLIENT_ID="netbird-backend"
NETBIRD_IDP_MGMT_CLIENT_SECRET="<CLIENT_SECRET_HERE>"
NETBIRD_IDP_MGMT_EXTRA_ADMIN_ENDPOINT="https://your-keycloak-domain.example.com/admin/realms/netbird"
```

## Troubleshooting & Resolutions

| Symptom                                  | Cause                                                          | Resolution                                                                                      |
| ---------------------------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 401 “token invalid” after login          | Backend client lacked required role in Keycloak                | Assign `view-users` role (or equivalent) to `netbird-backend` client; verify JWT contains role. |
| Peers appear offline or cannot join      | Mismatched ports or relay secret mis-configured                | Ensure ports in Docker Compose align with Caddy routing; verify TURN/relay secret consistency.  |
| WebSocket/gRPC connection failures       | Reverse proxy not configured for WebSocket/grpc or wrong ports | Update Caddyfile to support `h2c` for HTTP/2 or WebSocket headers; verify internal ports.       |
| NAT traversal fails (strict NAT clients) | UDP ports for TURN/relay blocked                               | Open UDP 3478 and 49152-65535; check coturn logs.                                               |
| SSL certificate issues                   | Domain mis-match or ACME endpoint mis-configured               | Confirm DNS and ACME logs; verify Caddy certificate issuance.                                   |

## Validation & Operations

* Access `https://your-netbird-domain.example.com`, login via Keycloak and confirm user appears in dashboard.
* On a client device, install NetBird agent, authenticate, join network. Confirm the peer appears **online** in the dashboard.
* Test connectivity between peers (ping/traceroute).
* Monitor container status (`docker compose ps`) and logs (`docker compose logs --tail 50 management`, `signal`, `coturn`).
* Validate TLS certificate is valid and auto-renewed by Caddy.
* Periodically test from restrictive networks (behind symmetric NAT) to confirm relay fallback functionality.

## Summary

This documentation provides a comprehensive, viewer-safe guide for deploying a self-hosted NetBird overlay network with Keycloak as IAM and Caddy as the TLS termination/reverse proxy layer. Key elements include correct domain mapping, consistent environment variable configuration, proper OIDC/IDP settings, reverse proxy support for gRPC/ WebSocket, and aligned secrets. Once configured correctly, peers should be displayed online and inter-connect securely.
