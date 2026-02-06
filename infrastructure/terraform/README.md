# NetBird GKE Deployment (Production Grade)

This configuration provides a highly available, production-ready NetBird deployment on GKE.

## High Availability Architecture
- **State Management**: Terraform state is stored in a GCS bucket.
- **Database**: Regional Cloud SQL (PostgreSQL) with automated backups and HA failover.
- **Application**: Multi-replica deployment (3 nodes by default) for Management and Dashboard.
- **Scalability**: Configured with resource requests/limits and compatible with Horizontal Pod Autoscaler.

## Prerequisites
1. **GCS Bucket**: Create a bucket for Terraform state (see `backend.tf`).
2. **GKE Cluster**: A regional GKE cluster is recommended for production.
3. **APIs Enabled**: Ensure `sqladmin.googleapis.com` is enabled in your GCP project.

## Configuration
Update `terraform.tfvars` with production values:
```hcl
replica_count    = 3
db_instance_tier = "db-custom-2-7680" # Production-grade tier
```

## Infrastructure Toggles

The project is highly modular. You can toggle the following components in `terraform.tfvars`:

| Variable | Description | Default |
|----------|-------------|---------|
| `install_cert_manager` | Installs cert-manager and a Let's Encrypt ClusterIssuer | `false` |
| `install_ingress_nginx` | Installs the Nginx Ingress Controller | `false` |
| `use_external_db` | Uses Regional Cloud SQL (PostgreSQL). If `false`, fallbacks to **SQLite**. | `true` |

> **Note**: For production, it is highly recommended to keep `use_external_db = true` to ensure data persistence and high availability.

## Configuration

1.  **Terraform Variables**:
    Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the required values:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

2.  **Official Helm Chart**:
    This project uses the official NetBird Helm chart from `https://netbirdio.github.io/helms`. It consolidates Management, Signal, Relay, and Dashboard into a single deployment.

3.  **Keycloak Automation**:
    The Terraform script now automatically creates:
    -   The `netbird` realm.
    -   The `netbird-management` client (confidential) with service account roles.
    -   The `netbird-dashboard` client (public).
    -   Necessary OIDC scopes and role mappings.

    You only need to provide the Keycloak admin credentials in your `terraform.tfvars`.

## Deployment

1.  **Initialize**:
    ```bash
    terraform init
    ```

2.  **Plan**:
    ```bash
    terraform plan
    ```

3.  **Apply**:
    ```bash
    terraform apply
    ```

## Components Deployed

-   **NetBird Management**: API and GRPC server.
-   **NetBird Signal**: Coordination server for peer connections.
-   **NetBird Dashboard**: Web UI.
-   **Coturn**: TURN/STUN server for NAT traversal (LoadBalancer provided).
-   **Cert-Manager** (Optional): Manages TLS certificates via Let's Encrypt.
-   **Ingress-Nginx** (Optional): Routes traffic to NetBird services.

## Post-Deployment Steps

### 1. DNS Configuration
Point your domain names to the external IP of the Ingress controller and Coturn LoadBalancer:
- `netbird.example.com` -> Ingress IP
- `netbird-mgmt.example.com` -> Ingress IP
- `netbird-signal.example.com` -> Ingress IP

### 2. Keycloak Verification
The Terraform script automatically configures Keycloak. Verify:
- Realm `netbird` exists.
- Client `netbird-management` is Confidential with Service Accounts enabled.
- Client `netbird-dashboard` is Public.
- Client Scopes include `api`.

## Accessing NetBird

Once the deployment is complete and DNS records are updated, you can access your NetBird instance at:

-   **Dashboard**: `https://netbird.example.com`
-   **Management API**: `https://netbird-mgmt.example.com`
-   **Signal Server**: `https://netbird-signal.example.com`
