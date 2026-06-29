# Landscape Database Server Deployment Guide

## Summary

This guide covers the deployment of the Landscape PostgreSQL database server using Ansible. The configuration has been converted from Puppet to Ansible following the existing patterns in the svw-ansible repository.

## Server Information

- **Hostname**: landscape
- **IP Address**: 10.10.7.242
- **Network**: 10.10.7.242/21
- **Platform**: Proxmox VM

## What Was Created

### 1. Ansible Role: `svwi-landscape`
Location: `/home/jhansen/Code/svw-ansible/roles/svwi-landscape/`

Structure:
```
svwi-landscape/
├── defaults/
│   └── main.yml          # Default variables
├── handlers/
│   └── main.yml          # Service handlers (restart/reload)
├── tasks/
│   └── main.yml          # Main deployment tasks
├── templates/
│   └── db-backup.sh.j2   # Backup script template
└── README.md             # Detailed role documentation
```

### 2. Playbook: `landscape-server.yml`
Location: `/home/jhansen/Code/svw-ansible/playbooks/landscape-server.yml`

Includes roles:
- svwi-users
- svwi-basenode
- svwi-landscape

### 3. Inventory Entry
Updated: `/home/jhansen/Code/svw-ansible/inventory.ini`

```ini
[landscape-server]
landscape ansible_host=10.10.7.242
```

### 4. Host Variables
Location: `/home/jhansen/Code/svw-ansible/host_vars/landscape.yml`

### 5. Deployment Script
Location: `/home/jhansen/Code/svw-ansible/playbooks/deploy-landscape.sh`

## Features Implemented

### PostgreSQL Setup
- ✅ PostgreSQL 16 installation via official APT repository
- ✅ Configuration: max_connections=400, max_prepared_transactions=400
- ✅ Network access from 10.10.0.0/16
- ✅ Superuser role: `landscape_superuser`
- ✅ Extensions: postgresql-debversion, postgresql-plpython3-16
- ✅ pg_hba.conf rules for landscape users

### Backup System
- ✅ Daily backups at 2:00 AM via cron
- ✅ Full database dump using pg_dumpall
- ✅ Gzip compression
- ✅ GCP bucket upload integration
- ✅ Automatic cleanup (7 days local if GCP succeeds, 30 days if fails)
- ✅ Logging to /var/log/pg-backup.log

### Vault Integration
- ✅ Vault agent installation and configuration
- ✅ AppRole authentication
- ✅ Token persistence at /run/vault-postgres/landscape.token
- ✅ GCP credentials retrieval for backups
- ✅ Systemd service: landscape-vault-agent

### Security
- ✅ Proper file permissions (postgres user for backups)
- ✅ Vault credentials stored securely
- ✅ No hardcoded passwords
- ✅ Unattended-upgrades installed

## Prerequisites

Before deployment, ensure the following are configured in `vault.yml`:

```yaml
# You need to add these entries to your encrypted vault.yml file
landscape_superuser_pw: "your-secure-password-here"
landscape_role_id: "vault-approle-role-id"
landscape_secret_id: "vault-approle-secret-id"
```

To edit vault.yml:
```bash
cd /home/jhansen/Code/svw-ansible
ansible-vault edit vault.yml --vault-password-file .vault.pass
```

## Deployment Instructions

### Option 1: Using the Deployment Script (Recommended)

```bash
cd /home/jhansen/Code/svw-ansible
./playbooks/deploy-landscape.sh
```

When prompted, enter your sudo password for the landscape server.

### Option 2: Manual Deployment

```bash
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass
```

### Option 3: Dry Run (Check Mode)

To see what would change without making actual changes:

```bash
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass --check
```

### Option 4: Verbose Debugging

For troubleshooting:

```bash
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass -vvv
```

## Post-Deployment Verification

### 1. Check PostgreSQL Status

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status postgresql" --ask-become-pass
```

### 2. Verify PostgreSQL Version

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres psql -c 'SELECT version();'" --ask-become-pass
```

### 3. Check Database Users

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres psql -c '\du'" --ask-become-pass
```

### 4. Verify Vault Agent

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status landscape-vault-agent" --ask-become-pass
```

### 5. Test Backup Script

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres /usr/local/bin/pg-backup.sh" --ask-become-pass
```

### 6. Check Backup Logs

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "tail -30 /var/log/pg-backup.log" --ask-become-pass
```

### 7. Verify Cron Job

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "crontab -u postgres -l" --ask-become-pass
```

## Differences from Puppet Implementation

| Aspect | Puppet | Ansible |
|--------|--------|---------|
| PostgreSQL Module | puppetlabs/postgresql | Native apt + postgresql_user |
| Vault Agent | Custom vault_secrets::approle_agent | Manual systemd service config |
| Package Repo | Module managed | Explicit apt_key + apt_repository |
| File Templates | .erb templates | .j2 (Jinja2) templates |
| Service Management | Puppet service resource | systemd module |

## Troubleshooting

### Issue: Cannot connect via SSH
**Solution**: Ensure your SSH key is authorized on the landscape server for user jhansen.

### Issue: Sudo password fails
**Solution**: Verify jhansen user has sudo privileges on the landscape server.

### Issue: PostgreSQL won't start
**Solution**: Check logs with:
```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "journalctl -u postgresql -n 50" --ask-become-pass
```

### Issue: Vault agent fails to start
**Solution**: 
1. Verify vault credentials in vault.yml
2. Check vault agent logs:
```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "journalctl -u landscape-vault-agent -n 50" --ask-become-pass
```

### Issue: Backup script fails
**Solution**: 
1. Check log file: `/var/log/pg-backup.log`
2. Verify vault token exists: `/run/vault-postgres/landscape.token`
3. Manually run script as postgres user to see errors

## Network Configuration

The landscape server has the following network interfaces:
- **lo**: 127.0.0.1/8 (loopback)
- **ens18**: 10.10.7.242/21 (primary)
- **docker0**: 172.17.0.1 (if docker installed)

PostgreSQL is configured to listen on all interfaces but restricts access via pg_hba.conf to the 10.10.0.0/16 network.

## Files to Review

1. **Role tasks**: `roles/svwi-landscape/tasks/main.yml`
2. **Backup script**: `roles/svwi-landscape/templates/db-backup.sh.j2`
3. **Default variables**: `roles/svwi-landscape/defaults/main.yml`
4. **Playbook**: `playbooks/landscape-server.yml`
5. **Host config**: `host_vars/landscape.yml`

## Next Steps

1. ✅ Add vault credentials to vault.yml
2. ✅ Run deployment script or playbook
3. ✅ Verify PostgreSQL is running
4. ✅ Test backup script manually
5. ✅ Wait for scheduled backup (2 AM) or trigger manually
6. ✅ Verify GCP bucket has backups
7. ✅ Configure Landscape application to connect to this database

## Support

For issues or questions:
- Review the role README: `roles/svwi-landscape/README.md`
- Check Ansible documentation: https://docs.ansible.com
- Review original Puppet code: `puppet/site-modules/svwi_landscape/`

