all:
  vars:
    # NetBird Configuration
    netbird_domain: "${netbird_domain}"
    netbird_version: "${netbird_version}"
    coturn_version: "${coturn_version}"
    caddy_version: "${caddy_version}"
    haproxy_version: "${haproxy_version}"
    haproxy_image: "haproxy:${haproxy_version}"
    proxy_type: "${proxy_type}"
    acme_provider: "${acme_provider}"
    acme_server: "${acme_provider == "letsencrypt" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme.zerossl.com/v2/DV90"}"
    acme_email: "${acme_email}"
    acme_account_thumbprint: "${acme_account_thumbprint}"
    docker_compose_version: "${docker_compose_version}"
    netbird_log_level: "${netbird_log_level}"
    netbird_admin_email: "${netbird_admin_email}"
    netbird_admin_password: "${netbird_admin_password}"
    relay_auth_secret: "${relay_auth_secret}"
    netbird_encryption_key: "${netbird_encryption_key}"
    coturn_password: "${coturn_password}"
    coturn_port: ${coturn_port}
    coturn_min_port: ${coturn_min_port}
    coturn_max_port: ${coturn_max_port}
    coturn_realm: "${coturn_realm}"

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
    db_channel_binding: "${database_channel_binding}"
    sqlite_database_path: "${sqlite_database_path}"

    # Keycloak Configuration
    keycloak_url: "${keycloak_url}"
    keycloak_realm: "${keycloak_realm}"
    keycloak_client_id: "${keycloak_client_id}"
    keycloak_backend_client_id: "${keycloak_backend_client_id}"
    keycloak_backend_client_secret: "${keycloak_backend_client_secret}"
    keycloak_oidc_endpoint: "${keycloak_oidc_endpoint}"
    
    # HA Configuration
    enable_clustering: ${enable_clustering}
    netbird_cluster_port: ${netbird_cluster_port}
    enable_pgbouncer: ${enable_pgbouncer}
    
    # PgBouncer Configuration (ALL required variables)
    netbird_state: "present"
    pgbouncer_state: "present"
    pgbouncer_version: "latest"
    pgbouncer_listen_address: "0.0.0.0"
    pgbouncer_listen_port: ${pgbouncer_listen_port}
    pgbouncer_database_name: "${database_name}"
    pgbouncer_database_host: "${database_endpoint}"
    pgbouncer_database_port: ${database_port}
    pgbouncer_database_user: "${database_username}"
    pgbouncer_database_password: "${database_password}"
    pgbouncer_database_sslmode: "${database_sslmode}"
    pgbouncer_database_channel_binding: "${database_channel_binding}"
    pgbouncer_min_pool_size: ${pgbouncer_min_pool_size}
    pgbouncer_default_pool_size: ${pgbouncer_default_pool_size}
    pgbouncer_reserve_pool_size: ${pgbouncer_reserve_pool_size}
    pgbouncer_reserve_pool_timeout: ${pgbouncer_reserve_pool_timeout}
    pgbouncer_pool_mode: "${pgbouncer_pool_mode}"
    pgbouncer_server_lifetime: ${pgbouncer_server_lifetime}
    pgbouncer_server_idle_timeout: ${pgbouncer_server_idle_timeout}
    pgbouncer_query_timeout: ${pgbouncer_query_timeout}
    pgbouncer_query_wait_timeout: ${pgbouncer_query_wait_timeout}
    pgbouncer_client_idle_timeout: ${pgbouncer_client_idle_timeout}
    pgbouncer_max_client_conn: ${pgbouncer_max_client_conn}
    pgbouncer_max_db_connections: ${pgbouncer_max_db_connections}
    pgbouncer_max_user_connections: ${pgbouncer_max_user_connections}
    pgbouncer_log_connections: "1"
    pgbouncer_log_disconnections: "1"
    pgbouncer_log_pooler_errors: "1"
    pgbouncer_stats_period: ${pgbouncer_stats_period}
    pgbouncer_health_check_period: ${pgbouncer_health_check_period}
    pgbouncer_health_check_timeout: ${pgbouncer_health_check_timeout}
    
    # HAProxy Configuration
    haproxy_health_check_interval: ${haproxy_health_check_interval}
    haproxy_health_check_timeout: ${haproxy_health_check_timeout}
    haproxy_health_check_fall: ${haproxy_health_check_fall}
    haproxy_health_check_rise: ${haproxy_health_check_rise}
    haproxy_stick_table_size: "${haproxy_stick_table_size}"
    haproxy_stick_table_expire: "${haproxy_stick_table_expire}"
    haproxy_stats_uri: "/stats"
    haproxy_stats_refresh: 5
    haproxy_stats_password: "${haproxy_stats_password}"
    
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
