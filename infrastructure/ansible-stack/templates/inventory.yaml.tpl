all:
  vars:
    # NetBird Configuration
    netbird_domain: "${netbird_domain}"
    netbird_version: "${netbird_version}"
    coturn_version: "${coturn_version}"
    caddy_version: "${caddy_version}"
    acme_provider: "${acme_provider}"
    acme_email: "${acme_email}"
    docker_compose_version: "${docker_compose_version}"
    netbird_log_level: "${netbird_log_level}"
    relay_auth_secret: "${relay_auth_secret}"
    netbird_encryption_key: "${netbird_encryption_key}"
    coturn_password: "${coturn_password}"

    # Paths
    netbird_data_dir: "/var/lib/netbird"
    netbird_config_dir: "/etc/netbird"

    # Database Configuration
    database_type: "${database_type}"
    database_engine: "${database_engine}"
    database_dsn: "${database_dsn}"
    database_endpoint: "${database_endpoint}"
    db_host: "${database_endpoint}"
    db_port: ${database_port}
    db_name: "${database_name}"
    db_user: "${database_username}"
    db_password: "${database_password}"
    db_sslmode: "${database_sslmode}"
    sqlite_database_path: "${sqlite_database_path}"

    # Keycloak Configuration
    keycloak_url: "${keycloak_url}"
    keycloak_realm: "${keycloak_realm}"
    keycloak_client_id: "${keycloak_client_id}"
    keycloak_backend_client_id: "${keycloak_backend_client_id}"
    keycloak_backend_client_secret: "${keycloak_backend_client_secret}"
    keycloak_oidc_endpoint: "${keycloak_oidc_endpoint}"
    
    # Relay & STUN Addresses
    relay_addresses: ${jsonencode(relay_addresses)}
    stun_addresses: ${jsonencode(stun_addresses)}

    # Ansible Connection
    ansible_ssh_private_key_file: "${ssh_private_key_path}"
    
  children:
    management:
      hosts:
%{ for node in management_nodes ~}
        ${node.hostname}:
          ansible_host: ${node.public_ip}
          private_ip: ${node.ip}
          ansible_user: ${node.ssh_user}
%{ endfor ~}
    reverse_proxy:
      hosts:
%{ for node in reverse_proxy_nodes ~}
        ${node.hostname}:
          ansible_host: ${node.public_ip}
          private_ip: ${node.ip}
          ansible_user: ${node.ssh_user}
%{ endfor ~}
    relay:
      hosts:
%{ for node in relay_nodes ~}
        ${node.hostname}:
          ansible_host: ${node.public_ip}
          private_ip: ${node.ip}
          ansible_user: ${node.ssh_user}
          relay_domain: ${node.public_ip}
%{ endfor ~}
