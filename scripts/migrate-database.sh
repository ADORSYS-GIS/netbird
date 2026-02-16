#!/bin/bash
# Helper script to migrate NetBird from SQLite to PostgreSQL

set -e

# Configuration
NETBIRD_IMAGE="netbirdio/netbird:latest"
DATA_DIR="/var/lib/netbird"
SQLITE_DB="${DATA_DIR}/store.db"
EXPORT_FILE="${DATA_DIR}/export.json"
BACKUP_FILE="${SQLITE_DB}.backup.$(date +%Y%m%d%H%M%S)"

echo "=== NetBird Database Migration Tool ==="
echo "This script migrates data from SQLite to PostgreSQL."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Check if SQLite DB exists
if [ ! -f "$SQLITE_DB" ]; then
    echo "Error: SQLite database not found at $SQLITE_DB"
    exit 1
fi

echo "Step 1: Exporting SQLite data..."
# Stop service first
echo "Stopping NetBird service..."
docker-compose -f /etc/netbird/docker-compose.yml stop || true

# Backup
echo "Creating backup at $BACKUP_FILE"
cp "$SQLITE_DB" "$BACKUP_FILE"

# Export
echo "Running export command..."
docker run --rm \
  -v "${DATA_DIR}:/data" \
  "$NETBIRD_IMAGE" \
  migrate export --source /data/store.db --output /data/export.json

if [ -f "$EXPORT_FILE" ]; then
    echo "✓ Export successful: $EXPORT_FILE"
else
    echo "✗ Export failed!"
    exit 1
fi

echo ""
echo "Step 2: Preparing for Import"
echo "Please provide the PostgreSQL connection string (DSN)."
echo "Format: host=postgres.example.com port=5432 dbname=netbird user=netbird password=SECRET sslmode=require"
read -p "Postgres DSN: " PG_DSN

if [ -z "$PG_DSN" ]; then
    echo "Error: DSN cannot be empty."
    exit 1
fi

echo ""
echo "Step 3: Importing to PostgreSQL..."
docker run --rm \
  -v "${DATA_DIR}:/data" \
  -e POSTGRES_DSN="$PG_DSN" \
  "$NETBIRD_IMAGE" \
  migrate import --source /data/export.json

if [ $? -eq 0 ]; then
    echo "✓ Import completed successfully!"
    echo ""
    echo "Next Steps:"
    echo "1. Update your Terraform config to use 'postgresql' type."
    echo "2. Run 'terraform apply'."
    echo "3. Run 'ansible-playbook' to update server config."
else
    echo "✗ Import failed."
    # Restore?
    echo "To restore SQLite services, run: docker-compose -f /etc/netbird/docker-compose.yml start"
    exit 1
fi
