all:
  vars:
    # NetBird Configuration
    netbird_domain: "${netbird_domain}"
    netbird_version: "${netbird_version}"
    relay_auth_secret: "${relay_auth_secret}"

    # Database Configuration
    database_type: "${database_type}"
    database_engine: "${database_engine}"
    database_dsn: "${database_dsn}"
    database_endpoint: "${database_endpoint}"
    sqlite_database_path: "${sqlite_database_path}"

    # Keycloak Configuration
    keycloak_url: "${keycloak_url}"
    keycloak_realm: "${keycloak_realm}"
    keycloak_client_id: "${keycloak_client_id}"
    keycloak_client_secret: "${keycloak_client_secret}"
    keycloak_oidc_endpoint: "${keycloak_oidc_endpoint}"
    
  children:
    management:
      hosts:
%{ for index, node in management_nodes ~}
        ${node.name}:
          ansible_host: ${node.public_ip != "" ? node.public_ip : node.private_ip}
          private_ip: ${node.private_ip}
%{ endfor ~}
    reverse_proxy:
      hosts:
%{ for index, node in reverse_proxy_nodes ~}
        ${node.name}:
          ansible_host: ${node.public_ip != "" ? node.public_ip : node.private_ip}
          private_ip: ${node.private_ip}
%{ endfor ~}
    relay:
      hosts:
%{ for index, node in relay_nodes ~}
        ${node.name}:
          ansible_host: ${node.public_ip != "" ? node.public_ip : node.private_ip}
          private_ip: ${node.private_ip}
%{ endfor ~}
