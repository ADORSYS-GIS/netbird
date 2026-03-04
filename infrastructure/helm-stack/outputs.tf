# =============================================================================
# Terraform Outputs
# =============================================================================

output "netbird_urls" {
  description = "NetBird service URLs"
  value = {
    dashboard = "https://${var.netbird_domain}"
    api       = "https://${var.netbird_domain}/api"
    grpc      = "https://${var.netbird_domain}:443"
    signal    = "https://${var.netbird_domain}:443"
  }
}

output "keycloak_configuration" {
  description = "Keycloak configuration for NetBird"
  value = {
    realm            = keycloak_realm.netbird.realm
    issuer_url       = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}"
    dashboard_client = var.keycloak_client_id
    backend_client   = var.keycloak_mgmt_client_id
    device_auth_url  = "${var.keycloak_url}/realms/${keycloak_realm.netbird.realm}/protocol/openid-connect/auth/device"
  }
}

output "cli_setup_command" {
  description = "Command to set up NetBird CLI"
  value       = <<-EOT
    netbird up \
      --management-url https://${var.netbird_domain} \
      --admin-url https://${var.netbird_domain}
  EOT
}

output "important_notes" {
  description = "Important deployment notes"
  value       = <<-EOT
    
    ============================================================
    NetBird Deployment Complete!
    ============================================================
    
    Dashboard URL: https://${var.netbird_domain}
    
    To connect a peer, install NetBird client and run:
      netbird up --management-url https://${var.netbird_domain}
    
    Configuration:
    - Keycloak Realm: ${var.keycloak_realm}
    - Database: ${var.db_type == "postgres" ? (var.create_db ? "PostgreSQL (Cloud SQL)" : "PostgreSQL (Existing/External)") : "SQLite"}
    - Replicas: ${var.replica_count}
    
    Initial Admin User: ${var.netbird_admin_email}
    (Password must be changed on first login)
    
    ============================================================
  EOT
}

