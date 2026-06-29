#!/bin/bash
# Deployment script for Landscape Database Server
# This script will deploy the Landscape PostgreSQL server configuration

set -e

cd "$(dirname "$0")/.."

echo "======================================"
echo "Landscape Database Server Deployment"
echo "======================================"
echo ""
echo "Target: landscape (10.10.7.242)"
echo ""

# Check if we can reach the server
echo "Testing connectivity..."
if ! ansible landscape-server -m ping -i inventory.ini -e "ansible_become=false" > /dev/null 2>&1; then
    echo "Error: Cannot connect to landscape server"
    exit 1
fi
echo "✓ Connectivity OK"
echo ""

# Run the playbook
echo "Running playbook..."
echo "You will be prompted for your sudo password."
echo ""

ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass "$@"

echo ""
echo "======================================"
echo "Deployment complete!"
echo "======================================"

