# Database Module

Unified database configuration module for NetBird.

## Supported Types

| Type | Mode | Description |
|------|------|-------------|
| `sqlite` | N/A | Local file-based database (development/testing) |
| `postgresql` | `existing` | Connect to existing PostgreSQL instance (production) |

## Usage

```hcl
module "database" {
  source = "../modules/database"

  database_type = "postgresql"
  database_mode = "existing"

  existing_postgresql_host     = "db.example.com"
  existing_postgresql_port     = 5432
  existing_postgresql_database = "netbird"
  existing_postgresql_username = "netbird"
  existing_postgresql_password = var.db_password
  existing_postgresql_sslmode  = "require"
}
```

## Outputs

- `database_dsn` - Connection string for application
- `database_endpoint` - Database host
- `database_port` - Database port
- `database_name` - Database name
