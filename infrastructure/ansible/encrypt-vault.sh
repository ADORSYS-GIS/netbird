#!/bin/bash

set -e

VAULT_FILE="group_vars/netbird_servers/vault.yml"
VAULT_PASS_FILE=".vault_pass"

echo "=== Ansible Vault Encryption Helper ==="
echo ""

if [ ! -f "$VAULT_FILE" ]; then
    echo "Error: Vault file not found at $VAULT_FILE"
    exit 1
fi

if ansible-vault view "$VAULT_FILE" &>/dev/null; then
    echo "Vault file is already encrypted."
    echo ""
    echo "Available operations:"
    echo "  1. View vault contents"
    echo "  2. Edit vault"
    echo "  3. Rekey vault (change password)"
    echo "  4. Decrypt vault"
    echo ""
    read -p "Select operation (1-4): " choice
    
    case $choice in
        1)
            ansible-vault view "$VAULT_FILE"
            ;;
        2)
            ansible-vault edit "$VAULT_FILE"
            ;;
        3)
            ansible-vault rekey "$VAULT_FILE"
            echo "Vault password updated successfully!"
            ;;
        4)
            ansible-vault decrypt "$VAULT_FILE"
            echo "Vault decrypted successfully!"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
else
    echo "Vault file is not encrypted yet."
    echo ""
    read -p "Do you want to encrypt it now? (y/n): " encrypt
    
    if [ "$encrypt" = "y" ] || [ "$encrypt" = "Y" ]; then
        ansible-vault encrypt "$VAULT_FILE"
        echo ""
        echo "Vault encrypted successfully!"
        echo ""
        echo "IMPORTANT: Store your vault password securely!"
        echo "  - For local use: Save it in .vault_pass (already in .gitignore)"
        echo "  - For GitHub Actions: Add it to repository secrets as ANSIBLE_VAULT_PASSWORD"
    else
        echo "Encryption cancelled."
        exit 0
    fi
fi
