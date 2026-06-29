#!/bin/bash
# Test script to verify landscape server connectivity and readiness

set -e

cd "$(dirname "$0")/.."

echo "======================================"
echo "Landscape Server Connection Test"
echo "======================================"
echo ""

# Test basic connectivity
echo "1. Testing SSH connectivity..."
if ansible landscape-server -m ping -i inventory.ini -e "ansible_become=false" > /dev/null 2>&1; then
    echo "   ✓ SSH connection successful"
else
    echo "   ✗ SSH connection failed"
    exit 1
fi

# Check OS version
echo ""
echo "2. Checking OS version..."
ansible landscape-server -i inventory.ini -m shell -a "lsb_release -d" -e "ansible_become=false" 2>/dev/null | grep -A1 "landscape |" | tail -1 || echo "   Could not determine OS"

# Check if PostgreSQL is already installed
echo ""
echo "3. Checking PostgreSQL status..."
if ansible landscape-server -i inventory.ini -m shell -a "dpkg -l | grep postgresql" -e "ansible_become=false" 2>/dev/null | grep -q "postgresql"; then
    echo "   ⚠ PostgreSQL appears to be already installed"
    ansible landscape-server -i inventory.ini -m shell -a "dpkg -l | grep postgresql | head -3" -e "ansible_become=false" 2>/dev/null | grep "^ii"
else
    echo "   ✓ PostgreSQL not yet installed (clean slate)"
fi

# Check disk space
echo ""
echo "4. Checking disk space..."
ansible landscape-server -i inventory.ini -m shell -a "df -h / | tail -1" -e "ansible_become=false" 2>/dev/null | grep -v "landscape |" || echo "   Could not check disk space"

# Check if vault is accessible
echo ""
echo "5. Testing Vault connectivity..."
if ansible landscape-server -i inventory.ini -m shell -a "curl -s -o /dev/null -w '%{http_code}' https://vault1.svwi.us:8200/v1/sys/health" -e "ansible_become=false" 2>/dev/null | grep -q "200"; then
    echo "   ✓ Vault is accessible"
else
    echo "   ⚠ Vault connectivity issue (may need CA certificates)"
fi

echo ""
echo "======================================"
echo "Pre-deployment check complete!"
echo "======================================"
echo ""
echo "To deploy, run:"
echo "  ./playbooks/deploy-landscape.sh"
echo ""
echo "Or manually:"
echo "  ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass"
echo ""

