# AWS Configuration
cloud_provider = "aws"
netbird_domain = "vpn.example.com" # REPLACE WITH YOUR DOMAIN
aws_region     = "us-east-1"       # REPLACE WITH YOUR REGION

# Database Configuration (SQLite for simplicity, or change to postgresql)
database_type        = "sqlite"
database_mode        = "existing"
sqlite_database_path = "/var/lib/netbird/store.db"
enable_ha            = false

# Keycloak Configuration
keycloak_url                 = "https://auth.example.com" # REPLACE WITH YOUR KEYCLOAK URL
keycloak_admin_client_secret = "CHANGE_ME"                # REPLACE WITH YOUR SECRET

# Tag Filters (match these to your EC2 tags)
aws_tag_filters = {
  management    = { Name = "tag:Role", Values = ["netbird-management"] }
  reverse_proxy = { Name = "tag:Role", Values = ["netbird-reverse-proxy"] }
  relay         = { Name = "tag:Role", Values = ["netbird-relay"] }
}
