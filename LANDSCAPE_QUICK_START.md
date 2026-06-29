# Landscape Database Server - Quick Start Guide

## Current Status ✅

The Ansible configuration has been successfully created and tested:

- ✅ **SSH Connectivity**: Working (user: svw)
- ✅ **Server**: landscape @ 10.10.7.242 (Ubuntu 24.04.3 LTS)
- ✅ **PostgreSQL 16**: Already installed on the server
- ✅ **Disk Space**: 21GB available (28% used)
- ⚠️ **Vault**: May need CA certificates (will be handled by svwi-basenode role)

## What Was Created

```
svw-ansible/
├── roles/svwi-landscape/          # New Ansible role
│   ├── defaults/main.yml          # Configuration variables
│   ├── handlers/main.yml          # Service handlers
│   ├── tasks/main.yml             # Deployment tasks
│   ├── templates/
│   │   └── db-backup.sh.j2        # Backup script
│   └── README.md                  # Detailed documentation
│
├── playbooks/
│   ├── landscape-server.yml       # Main playbook
│   ├── deploy-landscape.sh        # Deployment script
│   └── test-landscape-connection.sh  # Connection test
│
├── host_vars/
│   └── landscape.yml              # Host-specific config
│
├── inventory.ini                  # Updated with landscape entry
└── LANDSCAPE_DEPLOYMENT.md        # Full documentation
```

## Quick Deploy (3 Steps)

### Step 1: Verify Vault Credentials

Ensure these are set in your encrypted `vault.yml`:

```bash
cd /home/jhansen/Code/svw-ansible
ansible-vault edit vault.yml --vault-password-file .vault.pass
```

Add/verify these entries:
```yaml
# PostgreSQL user passwords
landscape_superuser_pw: "your-secure-password-1"
landscape_user_pw: "your-secure-password-2"
landscape_maintenance_pw: "your-secure-password-3"

# Landscape admin credentials
landscape_admin_email: "admin@example.com"
landscape_admin_name: "Landscape Administrator"
landscape_admin_password: "your-secure-admin-password"

# Vault integration (for backups)
landscape_role_id: "vault-approle-role-id"
landscape_secret_id: "vault-approle-secret-id"
```

### Step 2: Test Connection (Optional)

```bash
cd /home/jhansen/Code/svw-ansible
./playbooks/test-landscape-connection.sh
```

### Step 3: Deploy

**Option A - Using the deployment script:**
```bash
cd /home/jhansen/Code/svw-ansible
./playbooks/deploy-landscape.sh
```

**Option B - Direct ansible-playbook:**
```bash
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass
```

When prompted, enter the sudo password for the `svw` user on the landscape server.

## What Will Be Configured

1. **PostgreSQL 16**
   - Max connections: 400
   - Max prepared transactions: 400
   - Listen on all interfaces
   - Network access from 10.10.0.0/16
   - Users: `landscape_superuser`, `landscape`, `landscape_maintenance`
   - Extensions: debversion, plpython3, set_user
   - Databases: account-1, main, package, session, knowledge, resource-1

2. **Landscape Server**
   - Landscape Server application
   - RabbitMQ message broker
   - Apache web server with SSL modules
   - Web interface on ports 80/443
   - Admin user configured

3. **Backup System**
   - Daily backups at 2:00 AM
   - Full pg_dumpall with gzip compression
   - Upload to GCP bucket: svw-landscape-backups
   - Local retention: 7 days (with GCP) or 30 days (without)
   - Log file: /var/log/pg-backup.log

4. **Vault Integration**
   - Vault agent with AppRole authentication
   - Token at: /run/vault-postgres/landscape.token
   - Systemd service: landscape-vault-agent
   - Automatic GCP credential retrieval

5. **Security**
   - Unattended upgrades enabled
   - Proper file permissions
   - No hardcoded passwords
   - Encrypted vault credentials

## Post-Deployment Verification

### Quick Health Check
```bash
cd /home/jhansen/Code/svw-ansible

# Check PostgreSQL
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status postgresql" --ask-become-pass

# Check Vault Agent
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status landscape-vault-agent" --ask-become-pass

# Test backup script
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres /usr/local/bin/pg-backup.sh" --ask-become-pass
```

### Verify Database Access
```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres psql -c 'SELECT version();'" --ask-become-pass
```

### Check Backup Logs
```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "tail -20 /var/log/pg-backup.log" --ask-become-pass
```

## Important Notes

- **PostgreSQL Already Installed**: The server already has PostgreSQL 16 installed. The playbook will configure it properly.
- **Idempotent**: The playbook can be run multiple times safely.
- **Vault Credentials**: Required for GCP backup uploads. Without them, backups will only be stored locally.
- **Network**: Server is at 10.10.7.242/21 on the ens18 interface.

## Troubleshooting

### If deployment fails:
```bash
# Run with verbose output
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass -vvv
```

### If Vault agent fails:
```bash
# Check logs
ansible landscape-server -i inventory.ini -m shell \
  -a "journalctl -u landscape-vault-agent -n 50" --ask-become-pass
```

### If backup fails:
```bash
# Check the log
ansible landscape-server -i inventory.ini -m shell \
  -a "cat /var/log/pg-backup.log" --ask-become-pass
```

## Files to Review

- **Full Documentation**: `LANDSCAPE_DEPLOYMENT.md`
- **Role README**: `roles/svwi-landscape/README.md`
- **Playbook**: `playbooks/landscape-server.yml`
- **Tasks**: `roles/svwi-landscape/tasks/main.yml`
- **Backup Script**: `roles/svwi-landscape/templates/db-backup.sh.j2`

## Next Steps After Deployment

1. Verify PostgreSQL is running and accessible
2. Test backup script manually
3. Wait for scheduled backup (2 AM) or trigger manually
4. Verify GCP bucket has backups
5. Configure Landscape application to connect to this database server
6. Set up monitoring for backup success/failure

## Support

For detailed information, see:
- `LANDSCAPE_DEPLOYMENT.md` - Complete deployment guide
- `roles/svwi-landscape/README.md` - Role documentation

---

**Ready to deploy!** 🚀

Run: `./playbooks/deploy-landscape.sh`

