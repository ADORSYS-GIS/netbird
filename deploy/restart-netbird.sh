#!/bin/bash

# NetBird Client Secret Fix and Restart Script
# This script applies the OAuth client secret synchronization fix

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

echo "🔧 Applying NetBird Client Secret Fix..."
echo "========================================"

# Change to ansible directory
cd "$ANSIBLE_DIR"

echo "📋 Step 1: Updating environment configuration..."
ansible-playbook -i inventory/hosts.yml keycloak-only.yml --tags "environment,passwords" -v

echo ""
echo "🔐 Step 2: Synchronizing Keycloak client secrets..."
ansible-playbook -i inventory/hosts.yml keycloak-only.yml --tags "keycloak,configuration" -v

echo ""
echo "🔄 Step 3: Restarting NetBird services..."
ansible-playbook -i inventory/hosts.yml playbook.yml --tags "restart-services" -v

echo ""
echo "🏥 Step 4: Checking service health..."
ansible-playbook -i inventory/hosts.yml playbook.yml --tags "restart-health-check" -v

echo ""
echo "✅ NetBird client secret fix applied successfully!"
echo "🌐 Access your NetBird dashboard at: http://192.168.4.123:8081"
echo "🔐 Keycloak admin at: http://192.168.4.123:8080/admin"
echo ""
echo "🔍 If you still see authentication issues, check the logs:"
echo "   docker compose logs -f management"
echo "   docker compose logs -f keycloak"
