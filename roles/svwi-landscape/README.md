# Landscape Server Role

This Ansible role deploys a complete Canonical Landscape Server installation using `landscape-server-quickstart`, which handles all database and application setup automatically.

## Overview

This role provides:
- PostgreSQL 16 installation and configuration
- Landscape Server Quickstart automatic installation
- All Landscape databases created automatically (main, account, package, session, knowledge, resource)
- RabbitMQ message broker (included with quickstart)
- Nginx web server as reverse proxy
- Database backup with optional GCP integration via Vault
- Vault agent setup for secure credential management
- Automated daily backups at 2 AM

## Key Features

- **PostgreSQL 16** with optimized configuration for Landscape
- **Landscape Server Quickstart** for automatic setup and schema management
- **Azure AD OAuth** for enterprise single sign-on (SSO)
- **GCP Backups** via Vault integration for automated cloud backup uploads
- **Nginx Reverse Proxy** with WebSocket support
- **Vault Agent** for secure credential management
- **Client Reconnection Tools** for migrating from old servers

## Key Design Decision

This role uses **`landscape-server-quickstart`** instead of manual `landscape-server` installation. The quickstart package:
- Automatically creates all PostgreSQL databases
- Automatically creates landscape users with secure passwords
- Automatically runs schema migrations
- Automatically configures and starts all services
- Provides a working Landscape server out of the box

This approach is more reliable and maintainable than manually creating databases, users, and configuration.

## Requirements

- Ubuntu 24.04 LTS (Noble) - required for landscape-server-quickstart
- Ubuntu Pro subscription (free for personal use, up to 5 machines)
- SSH access to the target server
- Sudo privileges on the target server
- Vault credentials (role_id and secret_id) for GCP backups (optional)

## Role Variables

Default variables are defined in `defaults/main.yml`:

```yaml
# PostgreSQL version
postgres_version: "16"

# PostgreSQL configuration
max_connections: "400"
max_prepared_transactions: "400"
listen_addresses: "*"
pg_allowed_network: "10.10.0.0/16"

# Vault configuration (for backups)
vault_addr: "https://vault1.svwi.us:8200"
gcp_bucket: "svw-landscape-backups"
backup_dir: "/var/backups/postgresql"
log_file: "/var/log/pg-backup.log"

# Database credentials
landscape_superuser_pw: "{{ vault.super_user_pw | default('changeme') }}"

# Vault integration (optional, for GCP backups)
landscape_role_id: "{{ vault['landscape-role-id'] | default('') }}"
landscape_secret_id: "{{ vault['landscape-secret-id'] | default('') }}"

# Azure AD OAuth (optional, for SSO)
landscape_oidc_issuer: "{{ vault.landscape_oidc_issuer | default('') }}"
landscape_oidc_client_id: "{{ vault.landscape_oidc_client_id | default('') }}"
landscape_oidc_client_secret: "{{ vault.landscape_oidc_client_secret | default('') }}"
```

## Dependencies

This role requires:
- `community.postgresql` Ansible collection for PostgreSQL user management
- Ubuntu Pro subscription enabled on target server

Install required collections:
```bash
ansible-galaxy collection install community.postgresql
```

## Example Playbook

```yaml
---
- name: Deploy Landscape Server
  hosts: landscape-server
  become: true
  roles:
    - svwi-users
    - svwi-basenode
    - svwi-landscape
```

## Deployment Instructions

### 1. Prepare Target Server

Ensure Ubuntu Pro is enabled on the target:
```bash
ssh your-server
sudo pro attach YOUR_TOKEN
sudo pro enable landscape
```

### 2. Configure Inventory

Add your server to `inventory.ini`:
```ini
[landscape-server]
landscape ansible_host=10.10.7.242
```

### 3. Configure Host Variables

Create `host_vars/landscape.yml`:
```yaml
ansible_user: svw
ansible_become: true
ansible_python_interpreter: /usr/bin/python3
```

### 4. Run Deployment

```bash
cd /path/to/svw-ansible
bash playbooks/deploy-landscape.sh
```

Or manually:
```bash
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-become-pass
```

### 5. Verify Installation

After deployment completes:

```bash
# Check services are running
ssh your-server 'systemctl status landscape-appserver'

# Test web interface
curl http://your-server
```

Access the web UI at: `http://your-server` or `https://your-server`

## What Gets Installed

### PostgreSQL
- PostgreSQL 16 from official PGDG repository
- Custom configuration for Landscape workloads
- Network access configured (md5 authentication)
- Only `landscape_superuser` created by Ansible (quickstart creates the rest)

### Landscape Server
- `landscape-server-quickstart` package which includes:
  - All Landscape application services
  - RabbitMQ message broker
  - All required Python dependencies
  - Automatic database setup
  - Automatic schema migrations

### Nginx
- Reverse proxy configuration for Landscape services
- Proxies to ports: 8080 (app), 8081 (message), 8090 (ping), 8070 (api)

### Backup System
- PostgreSQL backup script: `/usr/local/bin/pg-backup.sh`
- Daily cron job running as postgres user at 2 AM
- Backup directory: `/var/backups/postgresql/`
- Backup log: `/var/log/pg-backup.log`
- Optional GCP upload via Vault integration

### Vault Agent (Optional)
- Runs as postgres user
- Uses AppRole authentication
- Provides GCP credentials for backup uploads
- Token stored at: `/run/vault-postgres/landscape.token`

## Backup Configuration

### Local Backups Only
If Vault credentials are not provided, backups are stored locally only:
- Location: `/var/backups/postgresql/`
- Retention: 30 days
- Format: `pg_all_dbs_YYYYMMDD_HHMMSS.sql.gz`

### With GCP Integration
If Vault credentials are provided:
- Backups are uploaded to GCP bucket
- Local retention: 7 days (kept for quick recovery)
- GCP bucket: `svw-landscape-backups` (configurable)

### Testing Backups
```bash
# Run backup manually
sudo -u postgres /usr/local/bin/pg-backup.sh

# Check backup log
tail -f /var/log/pg-backup.log

# List backups
ls -lh /var/backups/postgresql/
```

### Fixing Backup Issues

If backups are not working (Vault agent permission errors), run the fix script:
```bash
# Copy script to landscape server
scp playbooks/fix-landscape-backup.sh svw@10.10.7.242:~

# SSH to server
ssh svw@10.10.7.242

# Run script (will prompt for sudo password)
bash fix-landscape-backup.sh
```

This script will:
- Fix Vault agent credential file permissions
- Ensure backup directory exists with correct ownership
- Add missing cron job
- Restart Vault agent
- Run a test backup

## Azure AD OAuth Configuration

To enable Azure AD single sign-on:

1. **Set up Azure AD App Registration** - See [LANDSCAPE_AZURE_OAUTH.md](../../LANDSCAPE_AZURE_OAUTH.md)
2. **Add credentials to vault**:
   ```yaml
   landscape_oidc_issuer: "https://login.microsoftonline.com/{TENANT_ID}/v2.0/"
   landscape_oidc_client_id: "your-client-id"
   landscape_oidc_client_secret: "your-client-secret"
   ```
3. **Deploy configuration** with the playbook
4. **Test login** at your Landscape URL

For detailed setup instructions, see [LANDSCAPE_AZURE_OAUTH.md](../../LANDSCAPE_AZURE_OAUTH.md)

## Client Management

### Reconnecting Clients to New Server

If you've deployed a new Landscape server and need to reconnect existing clients that were using an old (deleted) server:

```bash
# On the client machine (as root):
cd /path/to/svw-ansible
sudo bash playbooks/reconnect-landscape-client.sh lds.svwi.us "Smart Vision Works" "YOUR_REGISTRATION_KEY"

# For HTTP (no SSL) servers:
sudo bash playbooks/reconnect-landscape-client.sh 10.10.7.242 "Default" "KEY" --insecure
```

The script will:
- Stop landscape-client service
- Remove old configuration and certificates
- Clear client state
- Register with new server
- Start service and verify registration

See script help for more options: `bash playbooks/reconnect-landscape-client.sh --help`

## Troubleshooting

### Landscape services not starting
```bash
# Check service status
systemctl status landscape-appserver landscape-api landscape-msgserver

# Check logs
journalctl -u landscape-appserver -n 100 --no-pager

# Restart all services
systemctl restart landscape-*
```

### Web UI not accessible
```bash
# Check nginx status
systemctl status nginx

# Check nginx config
nginx -t

# Check if Landscape is listening
ss -tlnp | grep :8080
```

### Backup failures
```bash
# Check backup log
cat /var/log/pg-backup.log

# Test backup manually
sudo -u postgres /usr/local/bin/pg-backup.sh

# Check Vault agent (if using GCP)
systemctl status landscape-vault-agent
journalctl -u landscape-vault-agent -n 50 --no-pager

# Fix permission issues
cd /path/to/svw-ansible
bash playbooks/fix-landscape-backup.sh
```

**Common issue:** Vault agent permission denied
- **Cause:** Credential files owned by root but agent runs as postgres
- **Fix:** Run `fix-landscape-backup.sh` script which corrects permissions

### Azure OAuth not working
```bash
# Check if OAuth config is present
sudo grep -A 3 "oidc-issuer" /etc/landscape/service.conf

# If missing, redeploy with playbook
cd /path/to/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-vault-pass

# Check Landscape service logs
journalctl -u landscape-appserver -n 100 --no-pager

# Restart services
sudo systemctl restart landscape-api landscape-appserver landscape-msgserver
```

**Common issues:**
- Redirect URI mismatch: Update redirect URI in Azure AD app registration
- Invalid secret: Check secret hasn't expired in Azure portal
- No OAuth button: Ensure all three OAuth variables are set and services restarted

### Database connection issues
```bash
# Check PostgreSQL is running
systemctl status postgresql

# Check pg_hba.conf
sudo cat /etc/postgresql/16/main/pg_hba.conf

# Test local connection
sudo -u postgres psql -l
```

## Upgrading

To upgrade Landscape Server:
```bash
ssh your-server
sudo apt update
sudo apt upgrade landscape-server-quickstart
sudo systemctl restart landscape-*
```

## Uninstalling

To completely remove Landscape and start fresh:
```bash
# Stop services
sudo systemctl stop landscape-*

# Remove packages
sudo apt-get purge -y landscape-server landscape-server-quickstart
sudo apt-get autoremove -y

# Drop databases
sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"landscape-standalone-account-1\";"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"landscape-standalone-main\";"
# ... repeat for all databases

# Clean configuration
sudo rm -rf /etc/landscape/*
sudo rm -rf /var/lib/landscape/*
sudo rm -rf /var/log/landscape/*
```

## License

Internal use only - Smart Vision Works

## Author

Converted from Puppet module `svwi_landscape` by Cursor/Claude
