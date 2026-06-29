# Landscape Server Recovery and Backup Setup Guide

## Current Situation

The Ansible playbook tried to reinstall `landscape-server` which broke the existing working installation created by `landscape-server-quickstart`. The quickstart package already includes landscape-server as a dependency, so reinstalling it caused configuration conflicts.

## Step 1: Fix the Broken Package State

Run this on the landscape server (as root or with sudo):

```bash
# SSH into the server
ssh svw@10.10.7.242

# Become root
sudo su -

# Option A: Force the package configuration to complete by bypassing the setup script
mv /var/lib/dpkg/info/landscape-server.postinst /var/lib/dpkg/info/landscape-server.postinst.bak
dpkg --configure -a
mv /var/lib/dpkg/info/landscape-server.postinst.bak /var/lib/dpkg/info/landscape-server.postinst

# Restart all Landscape services
systemctl restart landscape-*

# Wait a few seconds
sleep 10

# Test the web UI
curl -I http://localhost
```

If that works, your web UI should be back up.

## Step 2: Set Up Database Backups Manually

Since the backup configuration is already in place from Ansible, we just need to ensure Vault integration works:

```bash
# Check if backup script exists
ls -lh /usr/local/bin/pg-backup.sh

# Check backup directory
ls -ld /var/backups/postgresql

# Check cron job for postgres user
sudo crontab -l -u postgres | grep backup

# If cron job is missing, add it
sudo crontab -e -u postgres
# Add this line:
# 0 2 * * * /usr/local/bin/pg-backup.sh
```

## Step 3: Configure Vault Integration for GCP Backups

The backup script needs Vault credentials to upload to GCP. Check `/home/jhansen/Code/svw-ansible/roles/svwi-landscape/defaults/main.yml` for the required vault variables:

- `landscape_role_id` - from `vault['landscape-role-id']`
- `landscape_secret_id` - from `vault['landscape-secret-id']`

These need to be set in your vault or host_vars for the landscape server.

## Step 4: Test the Backup System

```bash
# On the landscape server, run the backup script manually as postgres user
sudo -u postgres /usr/local/bin/pg-backup.sh

# Check the backup log
sudo cat /var/log/pg-backup.log

# Check for backup files
ls -lh /var/backups/postgresql/

# If vault token is working, you should see GCP upload messages in the log
```

## Step 5: Verify Vault Agent (if using GCP uploads)

```bash
# Check if vault agent service exists and is configured
systemctl status landscape-vault-agent

# If not running, check the configuration
cat /etc/vault-agent.d/landscape-config.hcl

# Check if role_id and secret_id files exist
ls -l /etc/vault-agent.d/landscape-*

# If all looks good, start the service
systemctl start landscape-vault-agent
systemctl status landscape-vault-agent

# Check if token is being created
ls -l /run/vault-postgres/landscape.token
```

## Step 6: Re-run Ansible Playbook (Optional)

Once the server is fixed, you can re-run the Ansible playbook. The updated role will:
- Detect that quickstart is installed and skip landscape-server reinstall
- Still configure PostgreSQL, backups, vault agent, and nginx
- Not try to run schema upgrades (quickstart handles that)

```bash
cd /home/jhansen/Code/svw-ansible
bash playbooks/deploy-landscape.sh
```

## Verification Checklist

- [ ] Web UI is accessible at http://lds.svwi.us or http://10.10.7.242
- [ ] Backup script exists at `/usr/local/bin/pg-backup.sh`
- [ ] Backup directory exists at `/var/backups/postgresql`
- [ ] Cron job is configured for postgres user (runs daily at 2 AM)
- [ ] Vault agent is running (if using GCP uploads)
- [ ] Manual backup test completed successfully
- [ ] Backup log shows no errors at `/var/log/pg-backup.log`

## Backup Configuration Summary

The backup system works as follows:

1. **Daily Schedule**: Cron runs at 2 AM daily as postgres user
2. **Backup Process**:
   - Creates full PostgreSQL dump using `pg_dumpall`
   - Compresses with gzip
   - Saves to `/var/backups/postgresql/pg_all_dbs_TIMESTAMP.sql.gz`
3. **GCP Upload** (if Vault configured):
   - Reads Vault token from `/run/vault-postgres/landscape.token`
   - Gets GCP credentials from Vault
   - Uploads backup to `svw-landscape-backups` bucket
   - Keeps local backups for 7 days after successful upload
4. **Local-Only** (if Vault not configured):
   - Keeps local backups for 30 days
   - No GCP upload

## Troubleshooting

### Web UI not working after fix
```bash
sudo systemctl restart landscape-* nginx
sudo journalctl -u landscape-appserver -n 50 --no-pager
```

### Backup script fails
```bash
# Check script permissions
ls -l /usr/local/bin/pg-backup.sh
# Should be: -rwxr-x--- 1 postgres postgres

# Check postgres can run it
sudo -u postgres /usr/local/bin/pg-backup.sh
```

### GCP uploads not working
```bash
# Check vault agent logs
journalctl -u landscape-vault-agent -n 50 --no-pager

# Verify token exists
sudo ls -l /run/vault-postgres/landscape.token

# Test vault token manually
sudo -u postgres bash -c 'export VAULT_ADDR=https://vault1.svwi.us:8200 && curl -s --header "X-Vault-Token: $(cat /run/vault-postgres/landscape.token)" ${VAULT_ADDR}/v1/sys/health'
```
