#!/bin/bash
# Forward Multipass VM ports to localhost for browser access

VM_IP=$(cat inventory.ini | grep -E "^[0-9]" | head -1)

echo "Forwarding ports from Multipass VM ($VM_IP) to localhost..."
echo "You can access Keycloak at:"
echo "  HTTP:  http://localhost:8080"
echo "  HTTPS: https://localhost:8443"
echo ""
echo "Press Ctrl+C to stop forwarding"

# Forward HTTP (optional)
ssh -i ~/.ssh/ansible -L 8080:localhost:8080 -L 8443:localhost:443 -N ubuntu@$VM_IP
