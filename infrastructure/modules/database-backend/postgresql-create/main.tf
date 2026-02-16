# Helper to create managed Postgres instances
variable "cloud_provider" { type = string }
variable "instance_class" { type = string }
variable "storage_gb" { type = number }
variable "database_name" { type = string }
variable "username" { type = string }
variable "password" { type = string }
variable "multi_az" { type = bool }
variable "backup_retention_days" { type = number }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }

# AWS RDS
resource "aws_db_subnet_group" "netbird" {
  count      = var.cloud_provider == "aws" ? 1 : 0
  name_prefix = "netbird-db-"
  subnet_ids = var.subnet_ids
  tags = var.tags
}

resource "aws_db_instance" "netbird" {
  count = var.cloud_provider == "aws" ? 1 : 0

  identifier_prefix = "netbird-"
  engine     = "postgres"
  engine_version = "16.1"
  
  instance_class    = var.instance_class
  allocated_storage = var.storage_gb
  storage_type      = "gp3"
  storage_encrypted = true
  
  db_name  = var.database_name
  username = var.username
  password = var.password
  
  multi_az = var.multi_az
  backup_retention_period = var.backup_retention_days
  
  db_subnet_group_name   = aws_db_subnet_group.netbird[0].name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot    = true # For demo/simplicity, strictly in prod set to false
  
  tags = var.tags
}

# Add GCP/Azure resources similarly (omitted for brevity in this step, focusing on structure)

output "dsn" {
    value = var.cloud_provider == "aws" ? (
    "host=${aws_db_instance.netbird[0].address} port=${aws_db_instance.netbird[0].port} dbname=${var.database_name} user=${var.username} password=${var.password} sslmode=require"
  ) : "" # Placeholder for others
  sensitive = true
}

output "endpoint" {
    value = var.cloud_provider == "aws" ? aws_db_instance.netbird[0].address : ""
}
