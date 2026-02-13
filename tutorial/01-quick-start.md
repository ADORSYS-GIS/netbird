# Quick Start Tutorial

Deploy NetBird with Keycloak on your Kubernetes cluster in 6 steps.

---

## Prerequisites

- [ ] **Kubernetes cluster** (GKE, EKS, AKS, or self-managed) with `kubectl` access
- [ ] **Terraform** >= 1.0.0 installed
- [ ] **Helm** 3.x installed
- [ ] **Existing Keycloak** instance reachable via HTTPS
- [ ] **Domain name** you control (e.g., `netbird.example.com`)
- [ ] **DNS access** to create A records

---

## Step 1: Clone and Configure

```bash
# Clone the repository
git clone <repo-url>
cd netbird/infrastructure/terraform

# Create your configuration
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
# Required — GCP (adjust for your cloud)
project_id   = "my-gcp-project"
region       = "us-central1"
cluster_name = "my-gke-cluster"

# Required — NetBird domain
netbird_domain = "netbird.example.com"

# Required — Keycloak
keycloak_url            = "https://keycloak.example.com"
keycloak_admin_user     = "admin"
keycloak_admin_password = "your-keycloak-admin-password"

# Required — Admin user
netbird_admin_email    = "admin@example.com"
netbird_admin_password = "MyStr0ngP@ssword!"
```

---

## Step 2: Initialize and Plan

```bash
terraform init
terraform plan
```

Review the plan output. You should see resources for:
- Keycloak realm, clients, groups, mappers, admin user
- Kubernetes namespace, secrets
- NetBird Helm release (dashboard, management, signal, relay)

---

## Step 3: Apply

```bash
terraform apply
```

Type `yes` to confirm. This typically takes 3-5 minutes.

**Expected output**:
```
Apply complete! Resources: ~25 added, 0 changed, 0 destroyed.

Outputs:
netbird_dashboard_url = "https://netbird.example.com"
cli_setup_command = "netbird up --management-url https://netbird.example.com"
```

---

## Step 4: Create DNS Record

Get the LoadBalancer external IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Create an **A record** in your DNS provider:
```
netbird.example.com → <external-ip>
```

Wait for DNS propagation (1-5 minutes):
```bash
dig +short netbird.example.com
```

---

## Step 5: Log In

1. Open `https://netbird.example.com` in your browser
2. Click **Login**
3. You'll be redirected to Keycloak
4. Log in with the admin credentials from Step 1
5. **Change your password** (it's temporary)
6. You should see the NetBird dashboard

---

## Step 6: Verify Services

```bash
# All pods should be Running
kubectl get pods -n netbird

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# netbird-dashboard-xxx                   1/1     Running   0          5m
# netbird-management-xxx                  1/1     Running   0          5m
# netbird-signal-xxx                      1/1     Running   0          5m
# netbird-relay-xxx                       1/1     Running   0          5m

# Check ingress
kubectl get ingress -n netbird

# Check TLS certificate
kubectl get certificates -n netbird
```

---

## Next Steps

- [Tutorial 2: Adding Peers and ACLs](02-adding-peers-and-acls.md)
- [Tutorial 3: Keycloak User Management](03-keycloak-user-management.md)
- [Troubleshooting](../docs/troubleshooting.md)
