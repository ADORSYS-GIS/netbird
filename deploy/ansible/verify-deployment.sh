#!/bin/bash
# NetBird Ansible Deployment Verification Script
# This script verifies that all necessary files are present for deployment

set -e

echo "🔍 NetBird Ansible Deployment Verification"
echo "=========================================="

ANSIBLE_DIR="/home/usherking/projects/test/control-plane/netbird/netbird/deploy/ansible"
cd "$ANSIBLE_DIR"

# Check critical files
echo "📋 Checking critical files..."

CRITICAL_FILES=(
    "playbook.yml"
    "inventory/hosts.yml"
    "inventory/group_vars/all.yml"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
        exit 1
    fi
done

# Check role structure
echo ""
echo "📁 Checking role structure..."

ROLES=(
    "system-preparation"
    "netbird-environment" 
    "netbird-deployment"
    "keycloak-configuration"
)

for role in "${ROLES[@]}"; do
    if [[ -d "roles/$role/tasks" ]]; then
        task_count=$(find "roles/$role/tasks" -name "*.yml" | wc -l)
        echo "✅ $role ($task_count task files)"
    else
        echo "❌ $role - MISSING"
        exit 1
    fi
done

# Check templates
echo ""
echo "📄 Checking templates..."

TEMPLATES=(
    "netbird.env.j2"
    "docker-compose.yml.j2"
    "management.json.j2"
    "turnserver.conf.j2"
    "init-databases.sh.j2"
    "check-status.sh.j2"
    "backup.sh.j2"
    "update.sh.j2"
    "password-summary.txt.j2"
    "initial-passwords.txt.j2"
)

template_count=0
for template in "${TEMPLATES[@]}"; do
    if [[ -f "templates/$template" ]]; then
        echo "✅ $template"
        ((template_count++))
    else
        echo "❌ $template - MISSING"
    fi
done

echo ""
echo "📊 Summary:"
echo "  - Critical files: ${#CRITICAL_FILES[@]}/3 ✅"
echo "  - Roles: ${#ROLES[@]}/4 ✅"
echo "  - Templates: $template_count/${#TEMPLATES[@]} $([ $template_count -eq ${#TEMPLATES[@]} ] && echo '✅' || echo '⚠️')"

# Count total files
total_files=$(find . -name "*.yml" -o -name "*.j2" -o -name "*.md" -o -name "*.sh" | wc -l)
echo "  - Total files: $total_files"

echo ""
if [[ $template_count -eq ${#TEMPLATES[@]} ]]; then
    echo "🎉 DEPLOYMENT READY!"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Edit inventory/hosts.yml with your server details"
    echo "2. Test connectivity: ansible -i inventory/hosts.yml netbird -m ping"
    echo "3. Deploy: ansible-playbook -i inventory/hosts.yml playbook.yml"
    echo ""
    echo "📖 See DEPLOYMENT-GUIDE.md for detailed instructions"
else
    echo "⚠️ Some templates are missing. Deployment may not work correctly."
    exit 1
fi
