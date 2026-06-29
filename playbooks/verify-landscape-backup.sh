#!/bin/bash
# Script to verify Landscape backup configuration

set -e

TARGET_HOST="${1:-landscape}"
echo "=========================================="
echo "Landscape Backup Verification"
echo "=========================================="
echo ""
echo "Target: ${TARGET_HOST}"
echo ""

# Check backup script exists
echo "1. Checking backup script..."
if ssh svw@10.10.7.242 'test -f /usr/local/bin/pg-backup.sh'; then
    echo "   ✓ Backup script exists"
else
    echo "   ✗ Backup script not found"
    exit 1
fi

# Check backup directory exists
echo "2. Checking backup directory..."
if ssh svw@10.10.7.242 'test -d /var/backups/postgresql'; then
    echo "   ✓ Backup directory exists"
else
    echo "   ✗ Backup directory not found"
    exit 1
fi

# Check cron job
echo "3. Checking cron job..."
if ssh svw@10.10.7.242 'sudo crontab -l -u postgres 2>/dev/null | grep -q pg-backup'; then
    echo "   ✓ Cron job configured"
    ssh svw@10.10.7.242 'sudo crontab -l -u postgres | grep pg-backup'
else
    echo "   ✗ Cron job not found"
fi

# Check vault agent service
echo "4. Checking Vault agent..."
if ssh svw@10.10.7.242 'systemctl is-active landscape-vault-agent --quiet'; then
    echo "   ✓ Vault agent is running"
else
    echo "   ⚠ Vault agent is not running"
    echo "   Checking vault agent status..."
    ssh svw@10.10.7.242 'systemctl status landscape-vault-agent --no-pager -l' || true
fi

# Check vault token
echo "5. Checking Vault token..."
if ssh svw@10.10.7.242 'test -f /run/vault-postgres/landscape.token'; then
    echo "   ✓ Vault token exists"
    ssh svw@10.10.7.242 'ls -lh /run/vault-postgres/landscape.token'
else
    echo "   ✗ Vault token not found"
fi

# Test backup script (dry run)
echo "6. Testing backup script (creating test backup)..."
ssh svw@10.10.7.242 'sudo -u postgres /usr/local/bin/pg-backup.sh' || true

# Check for recent backups
echo "7. Checking for backup files..."
ssh svw@10.10.7.242 'ls -lh /var/backups/postgresql/ | tail -5'

# Check backup log
echo "8. Checking backup log..."
if ssh svw@10.10.7.242 'test -f /var/log/pg-backup.log'; then
    echo "   Recent log entries:"
    ssh svw@10.10.7.242 'tail -20 /var/log/pg-backup.log'
else
    echo "   ✗ Backup log not found"
fi

echo ""
echo "=========================================="
echo "Verification complete!"
echo "=========================================="
