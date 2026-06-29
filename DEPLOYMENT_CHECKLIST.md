# Landscape Deployment Checklist

## Pre-Deployment Status ✅

- [x] VM created and accessible: 10.10.7.242
- [x] SSH connectivity tested
- [x] Ansible role created
- [x] **Vault credentials verified** (using existing from Puppet)

## Credentials Already in vault.yml ✅

You already have the required credentials from your Puppet setup:

```yaml
super_user_pw: "..."              # PostgreSQL superuser (landscape_superuser)
landscape-role-id: "..."          # Vault role ID for backups
landscape-secret-id: "..."        # Vault secret ID for backups
```

**No additional credentials needed!** The Ansible role will:
- Use `super_user_pw` for the PostgreSQL superuser
- Auto-generate secure random passwords for internal database users
- Skip admin user creation (you'll configure Azure AD OAuth after installation)

## Deploy Now! 🚀

```bash
cd /home/jhansen/Code/svw-ansible
./playbooks/deploy-landscape.sh
```

Enter sudo password for `svw` user when prompted.

## What the Deployment Will Do

1. ✅ Configure PostgreSQL 16 with proper settings
2. ✅ Create PostgreSQL users:
   - `landscape_superuser` (with password from vault)
   - `landscape` (auto-generated password)
   - `landscape_maintenance` (auto-generated password)
3. ✅ Create 6 Landscape databases:
   - landscape-standalone-account-1
   - landscape-standalone-knowledge
   - landscape-standalone-main
   - landscape-standalone-package
   - landscape-standalone-resource-1
   - landscape-standalone-session
4. ✅ Install Landscape Server from Ubuntu Pro
5. ✅ Install and configure RabbitMQ
6. ✅ Install and configure Apache
7. ✅ Set up Vault agent for backups
8. ✅ Configure daily backups at 2 AM

## Post-Deployment Verification

### 1. Check All Services

```bash
cd /home/jhansen/Code/svw-ansible

# All services at once
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status postgresql landscape-server rabbitmq-server apache2 --no-pager" \
  --ask-become-pass
```

### 2. Verify Databases Created

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres psql -l | grep landscape" --ask-become-pass
```

Should show 6 databases.

### 3. Check Vault Agent

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "systemctl status landscape-vault-agent --no-pager" --ask-become-pass
```

## Configure Azure AD OAuth (After Deployment)

Once the base installation is complete, you'll need to configure Azure AD:

### 1. SSH to the server

```bash
ssh svw@10.10.7.242
```

### 2. Configure Landscape for Azure AD OAuth

Edit the Landscape configuration:

```bash
sudo nano /etc/landscape/service.conf
```

Add Azure AD OAuth configuration:

```ini
[landscape]
# ... existing config ...

# Azure AD OAuth
oidc-issuer = https://login.microsoftonline.com/<tenant-id>/v2.0
oidc-client-id = <your-client-id>
oidc-client-secret = <your-client-secret>
```

### 3. Restart Landscape Server

```bash
sudo systemctl restart landscape-server
```

### 4. Access Web Interface

Open browser to: **http://10.10.7.242** or **https://lds.svwi.us**

You should see the Azure AD login option.

## Client Enrollment

Once Landscape is running with Azure AD, enroll clients with:

```bash
sudo apt update
sudo apt install landscape-client -y

sudo landscape-config \
  --computer-title $(hostname) \
  --account-name standalone \
  -p <registration-key> \
  --url https://lds.svwi.us/message-system \
  --ping-url http://lds.svwi.us/ping \
  --include-manager-plugins=ScriptExecution \
  --script-users=root,landscape,nobody
```

You'll get the registration key from the Landscape web UI after configuring Azure AD.

## DNS Configuration

To use `lds.svwi.us` instead of IP:

1. Update DNS A record: `lds.svwi.us` → `10.10.7.242`
2. Wait for DNS propagation
3. Access via https://lds.svwi.us

## SSL Certificate Setup

After basic deployment works:

```bash
# SSH to server
ssh svw@10.10.7.242

# Install certbot
sudo apt install certbot python3-certbot-apache -y

# Get certificate
sudo certbot --apache -d lds.svwi.us
```

## Backup Configuration

Backups run daily at 2:00 AM:
- **Location**: /var/backups/postgresql/
- **Log**: /var/log/pg-backup.log
- **GCP upload**: Enabled (using vault credentials)
- **Retention**: 7 days local (if GCP succeeds), 30 days (if GCP fails)

### Test Backup Manually

```bash
ansible landscape-server -i inventory.ini -m shell \
  -a "sudo -u postgres /usr/local/bin/pg-backup.sh" --ask-become-pass

# Check log
ansible landscape-server -i inventory.ini -m shell \
  -a "tail -20 /var/log/pg-backup.log" --ask-become-pass
```

## Troubleshooting

### If deployment fails:

```bash
# Run with verbose output
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml \
  --ask-become-pass -vvv
```

### Check logs on server:

```bash
# SSH to server
ssh svw@10.10.7.242

# Landscape logs
sudo tail -f /var/log/landscape/server.log

# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-16-main.log

# Apache logs
sudo tail -f /var/log/apache2/error.log

# Check service status
sudo systemctl status landscape-server postgresql rabbitmq-server apache2
```

### PostgreSQL Connection Issues

```bash
# Test database connection
ssh svw@10.10.7.242
sudo -u postgres psql -l

# Check PostgreSQL is listening
sudo netstat -tlnp | grep 5432
```

### Landscape Won't Start

```bash
# Check configuration
ssh svw@10.10.7.242
sudo landscape-server --check-config

# Check service logs
sudo journalctl -u landscape-server -n 100
```

## Azure AD Configuration Details

When configuring Azure AD OAuth, you'll need:

1. **Tenant ID**: Your Azure AD tenant ID
2. **Client ID**: Application ID from Azure AD app registration
3. **Client Secret**: Secret from Azure AD app registration
4. **Redirect URI**: `https://lds.svwi.us/oauth/callback`

Make sure to configure these in your Azure AD app registration.

## Next Steps After Deployment

1. [ ] Run deployment script
2. [ ] Verify all services are running
3. [ ] Configure Azure AD OAuth
4. [ ] Access web interface
5. [ ] Create registration key
6. [ ] Enroll test client
7. [ ] Set up SSL certificates
8. [ ] Configure DNS
9. [ ] Enroll all remaining clients
10. [ ] Configure monitoring/alerting

## Documentation

- **Quick Start**: LANDSCAPE_QUICK_START.md
- **Full Guide**: LANDSCAPE_DEPLOYMENT.md
- **What Changed**: LANDSCAPE_COMPLETE_SERVER_UPDATE.md
- **Role Details**: roles/svwi-landscape/README.md

---

## Ready to Deploy!

Everything is configured. Just run:

```bash
cd /home/jhansen/Code/svw-ansible
./playbooks/deploy-landscape.sh
```

The deployment will take about 10-15 minutes. You'll see progress as it:
- Installs PostgreSQL 16
- Creates databases and users
- Installs Landscape Server
- Configures all services
- Sets up backups

After deployment completes, configure Azure AD OAuth for authentication.
