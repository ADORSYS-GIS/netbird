#!/bin/bash
# Pre-flight database connection validation

set -e

# Source Terraform outputs
cd infrastructure
DATABASE_TYPE=$(terraform output -raw database_type 2>/dev/null || echo "unknown")
DATABASE_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "unknown")

echo "=== NetBird Database Connection Validator ==="
echo "Database Type: $DATABASE_TYPE"
echo "Database Endpoint: $DATABASE_ENDPOINT"
echo ""

if [ "$DATABASE_TYPE" == "sqlite" ]; then
    echo "✓ SQLite mode - no connection test needed"
    echo "Database will be created locally on management nodes"
    exit 0
fi

if [ "$DATABASE_TYPE" == "postgresql" ]; then
    echo "Testing PostgreSQL connection..."
    DATABASE_DSN=$(terraform output -raw database_dsn)
    
    # Simple check if psql is installed
    if ! command -v psql &> /dev/null; then
        echo "WARNING: psql not found locally. Skipping local check."
        echo "The Ansible 'database-client' role will check this on the servers."
        exit 0
    fi
    
    if psql "$DATABASE_DSN" -c "SELECT version();" &>/dev/null; then
        echo "✓ PostgreSQL connection successful"
    else
        echo "✗ PostgreSQL connection FAILED"
        echo "Please check:"
        echo "  - Database endpoint is correct"
        echo "  - Security groups allow traffic from your IP"
        echo "  - Credentials are correct"
        exit 1
    fi
fi

if [ "$DATABASE_TYPE" == "mysql" ]; then
    echo "Testing MySQL connection..."
    echo "Note: Full MySQL validation requires parsing the DSN which is complex in bash."
    echo "Delegating check to Ansible."
fi

echo ""
echo "=== Connection Validation Complete ==="
