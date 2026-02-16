variable "database_type" { type = string }
variable "database_mode" { type = string }
variable "enable_ha" { type = bool }

# SQLite
variable "sqlite_database_path" { type = string }

# PostgreSQL Create
variable "cloud_provider" { type = string }
variable "postgresql_instance_class" { type = string }
variable "postgresql_storage_gb" { type = number }
variable "postgresql_database_name" { type = string }
variable "postgresql_username" { type = string }
variable "postgresql_password" { type = string }
variable "postgresql_multi_az" { type = bool }
variable "postgresql_backup_retention_days" { type = number }
variable "vpc_id" { type = string }
variable "database_subnet_ids" { type = list(string) }
variable "database_security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }

# PostgreSQL Existing
variable "existing_postgresql_host" { type = string }
variable "existing_postgresql_port" { type = number }
variable "existing_postgresql_database" { type = string }
variable "existing_postgresql_username" { type = string }
variable "existing_postgresql_password" { type = string }
variable "existing_postgresql_sslmode" { type = string }

# MySQL Existing
variable "existing_mysql_host" { type = string }
variable "existing_mysql_port" { type = number }
variable "existing_mysql_database" { type = string }
variable "existing_mysql_username" { type = string }
variable "existing_mysql_password" { type = string }
