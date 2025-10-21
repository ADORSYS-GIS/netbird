#!/bin/bash

# Script to manually clear dpkg locks
# Use this if the Ansible playbook still fails with lock issues

echo "=== Clearing dpkg locks ==="

# Check current lock status
echo "Current lock files:"
ls -la /var/lib/dpkg/lock* /var/cache/apt/archives/lock 2>/dev/null || echo "No lock files found"

# Find processes using the locks
echo -e "\nProcesses using lock files:"
for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock; do
    if [ -f "$lock" ]; then
        echo "Lock file: $lock"
        lsof "$lock" 2>/dev/null || echo "No process found for $lock"
    fi
done

# Kill unattended-upgrades if running
echo -e "\nChecking for unattended-upgrades..."
if pgrep -f unattended-upgr > /dev/null; then
    echo "Killing unattended-upgrades processes..."
    sudo pkill -f unattended-upgr
    sleep 5
else
    echo "No unattended-upgrades processes found"
fi

# Remove lock files
echo -e "\nRemoving lock files..."
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/cache/apt/archives/lock

# Reconfigure dpkg
echo -e "\nReconfiguring dpkg..."
sudo dpkg --configure -a

# Update package cache
echo -e "\nUpdating package cache..."
sudo apt update

echo -e "\n=== Done! You can now run the Ansible playbook again ==="
