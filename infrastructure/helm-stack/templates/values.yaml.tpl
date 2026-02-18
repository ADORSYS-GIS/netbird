domain: ${netbird_domain}

management:
  replicaCount: 2
  image:
    tag: ${netbird_version}
  config:
    encryption_key: ${netbird_encryption_key}
    store:
      engine: ${database_engine}
      dsn: ${database_dsn}
      host: ${database_host}
      port: ${database_port}
      name: ${database_name}
      user: ${database_user}
      password: ${database_pass}
      sslmode: ${database_sslmode}
    oidc:
      authority: ${keycloak_url}/realms/${keycloak_realm}
      client_id: ${keycloak_client_id}
      config_endpoint: ${keycloak_oidc_endpoint}

signal:
  replicaCount: 3
  image:
    tag: ${netbird_version}

dashboard:
  replicaCount: 2
  image:
    tag: ${netbird_version}
  env:
    NETBIRD_MGMT_API_ENDPOINT: \"https://${netbird_domain}\"
    NETBIRD_MGMT_GRPC_API_ENDPOINT: \"https://${netbird_domain}\"
    AUTH_AUDIENCE: \"${keycloak_client_id}\"
    AUTH_CLIENT_ID: \"${keycloak_client_id}\"
    AUTH_AUTHORITY: \"${keycloak_url}/realms/${keycloak_realm}\"
    AUTH_REDIRECT_URI: \"https://${netbird_domain}/nb-auth\"

relay:
  replicaCount: 2
  image:
    tag: ${netbird_version}
  auth:
    secret: ${relay_auth_secret}
