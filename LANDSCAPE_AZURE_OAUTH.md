# Landscape Server - Azure AD OAuth Configuration

This guide explains how to configure Azure AD OAuth authentication for your Landscape Server, allowing users to log in with their Microsoft accounts.

## Overview

Azure AD OAuth integration allows your organization to:
- Use existing Azure AD accounts for Landscape authentication
- Enable single sign-on (SSO) for users
- Centrally manage user access through Azure AD
- Eliminate the need for separate Landscape passwords

## Prerequisites

- Access to Azure Portal with permissions to create App Registrations
- Landscape Server deployed and accessible at a known URL (e.g., `https://lds.svwi.us` or `http://10.10.7.242`)
- Admin access to Landscape Server configuration

## Step 1: Register Application in Azure AD

### 1.1 Navigate to Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** (or **Microsoft Entra ID**)
3. Select **App registrations** from the left menu
4. Click **+ New registration**

### 1.2 Configure Basic Settings

**Name:** `Landscape Server` (or your preferred name)

**Supported account types:** Select based on your needs:
- **Single tenant** - Only your organization (recommended for internal use)
- **Multitenant** - Multiple organizations (if you have partners/subsidiaries)

**Redirect URI:**
- Platform: **Web**
- URI: `https://lds.svwi.us/login/handle-openid`

**CRITICAL:** The redirect URI must be exactly `/login/handle-openid` according to Landscape documentation.
Do NOT use `/oauth/callback`, `/login/oidc-callback`, or any other path.

Click **Register**

### 1.3 Note Application (Client) ID

After registration, you'll see the app overview page. Copy and save:
- **Application (client) ID** - This is your `oidc-client-id`
- **Directory (tenant) ID** - This is used in your `oidc-issuer`

Example:
```
Application (client) ID: a513c06b-f481-4e4e-8e8a-c7321eb51574
Directory (tenant) ID: 08b1bea8-9892-428f-b3a9-032db07ed2ce
```

## Step 2: Create Client Secret

### 2.1 Generate Secret

1. In your app registration, select **Certificates & secrets** from the left menu
2. Click **+ New client secret**
3. Description: `Landscape Server OAuth` (or your preferred name)
4. Expires: Choose expiration period (e.g., **24 months**)
   - **Important:** Note the expiration date in your calendar - you'll need to rotate this secret before it expires
5. Click **Add**

### 2.2 Copy Secret Value

**CRITICAL:** Copy the secret **Value** immediately - it will only be shown once!

Example:
```
Value: Zgn8Q~AbCdEfGhIjKlMnOpQrStUvWxYz0123456
Secret ID: 12345678-1234-1234-1234-123456789abc (you don't need this)
```

**Store this securely** - you'll need it for Landscape configuration.

## Step 3: Configure API Permissions (Optional)

If you want Landscape to read user profile information:

1. Select **API permissions** from the left menu
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Select **Delegated permissions**
5. Add these permissions:
   - `User.Read` - Read basic user profile
   - `email` - Read user's email address
   - `profile` - Read user's basic profile
6. Click **Add permissions**
7. Click **Grant admin consent** (if required by your organization)

## Step 4: Configure Landscape Server

### 4.1 Update Vault Configuration

Edit your vault file (encrypted):
```bash
cd /home/jhansen/Code/svw-ansible
ansible-vault edit vault.yml
```

Add these variables:
```yaml
# Azure AD OAuth Configuration
landscape_oidc_issuer: "https://login.microsoftonline.com/08b1bea8-9892-428f-b3a9-032db07ed2ce/v2.0/"
landscape_oidc_client_id: "a513c06b-f481-4e4e-8e8a-c7321eb51574"
landscape_oidc_client_secret: "Zgn8Q~AbCdEfGhIjKlMnOpQrStUvWxYz0123456"
```

**Format notes:**
- `oidc_issuer`: Use your **Directory (tenant) ID** in the URL: `https://login.microsoftonline.com/{TENANT_ID}/v2.0/`
- `oidc_client_id`: Your **Application (client) ID**
- `oidc_client_secret`: The secret **Value** you copied earlier

### 4.2 Deploy Configuration

**IMPORTANT:** Before running the playbook, ensure you have completed steps 1-3 above and have valid Azure AD credentials.

Run the Landscape playbook to apply the OAuth configuration:
```bash
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-vault-pass --ask-become-pass
```

Or use the deploy script:
```bash
bash playbooks/deploy-landscape.sh
```

The playbook will:
1. Add OAuth configuration to `/etc/landscape/service.conf` in the `[landscape]` section
2. Restart Landscape services to apply changes

**Note:** The OAuth settings are added using the `ini_file` module to properly place them in the `[landscape]` section of the config file.

### 4.3 Manual Configuration (Alternative)

If you prefer to configure manually on the server:

```bash
# SSH to landscape server
ssh svw@10.10.7.242

# Edit landscape config
sudo nano /etc/landscape/service.conf

# Add these lines under the [landscape] section (IMPORTANT: must be in the [landscape] section!):
oidc-issuer = https://login.microsoftonline.com/08b1bea8-9892-428f-b3a9-032db07ed2ce/v2.0/
oidc-client-id = a513c06b-f481-4e4e-8e8a-c7321eb51574
oidc-client-secret = Zgn8Q~AbCdEfGhIjKlMnOpQrStUvWxYz0123456

# The config should look like this:
# [landscape]
# message-system = rabbit
# message-system-host = localhost
# oidc-issuer = https://login.microsoftonline.com/.../v2.0/
# oidc-client-id = a513c06b-...
# oidc-client-secret = Zgn8Q~...
# ... other settings ...

# Restart landscape services
sudo systemctl restart landscape-api landscape-appserver landscape-msgserver
```

**CRITICAL:** The OAuth settings MUST be placed inside the `[landscape]` section, not as a separate section or at the end of the file. Placing them outside the section will cause Landscape to fail with validation errors.

## Step 5: Test OAuth Login

### 5.1 Access Landscape Web UI

1. Navigate to your Landscape server: `http://lds.svwi.us` or `http://10.10.7.242`
2. You should see a **Sign in with Microsoft** button (or similar OAuth login option)
3. Click the OAuth login button

### 5.2 Authenticate

1. You'll be redirected to Microsoft login page
2. Enter your Azure AD credentials
3. If prompted, accept the permissions requested by Landscape
4. You'll be redirected back to Landscape

### 5.3 Verify Access

After successful authentication:
- You should be logged into Landscape with your Azure AD identity
- Your username will be based on your Azure AD email/UPN
- Check that you can access the dashboard and manage systems

## Troubleshooting

### "Redirect URI mismatch" error

**Problem:** The redirect URI in Azure doesn't match the one Landscape is using.

**Solution:**
According to official Landscape documentation, the redirect URI must be:
```
https://lds.svwi.us/login/handle-openid
```

1. Go to Azure Portal → App registration → Authentication
2. **Remove all existing redirect URIs**
3. Add only: `https://lds.svwi.us/login/handle-openid`
4. Click Save

**Note:** Do NOT use `/oauth/callback`, `/login/oidc-callback`, or any other path. Landscape 25.10 requires `/login/handle-openid`.

### "Invalid client secret" error

**Problem:** The client secret is incorrect or has expired.

**Solution:**
1. Go to Azure Portal → App registration → Certificates & secrets
2. Check if your secret has expired
3. If expired or invalid, create a new secret
4. Update the `landscape_oidc_client_secret` in your vault.yml
5. Redeploy configuration or manually update `/etc/landscape/service.conf`

### OAuth button doesn't appear

**Problem:** Landscape services haven't picked up the OAuth configuration.

**Solution:**
```bash
# SSH to landscape server
ssh svw@10.10.7.242

# Check if OAuth config is present in the [landscape] section
sudo grep -A 20 "^\[landscape\]" /etc/landscape/service.conf | grep oidc

# If present, restart services
sudo systemctl restart landscape-api landscape-appserver landscape-msgserver

# Check service status
systemctl status landscape-appserver
```

### Landscape services fail to start after adding OAuth

**Problem:** OAuth configuration was added incorrectly (outside the `[landscape]` section).

**Symptoms:**
```
Extra inputs are not permitted [type=extra_forbidden, input_value='...', input_type=str]
```

**Solution:**
```bash
# SSH to landscape server
ssh svw@10.10.7.242

# Check where OAuth config is located
sudo cat /etc/landscape/service.conf

# If OAuth settings are NOT under [landscape] section, fix it:
# Option 1: Remove and re-add properly
sudo sed -i '/oidc-issuer/d; /oidc-client-id/d; /oidc-client-secret/d' /etc/landscape/service.conf

# Then manually add them in the [landscape] section
sudo nano /etc/landscape/service.conf

# Or Option 2: Redeploy with fixed Ansible role
cd /home/jhansen/Code/svw-ansible
ansible-playbook -i inventory.ini playbooks/landscape-server.yml --ask-vault-pass --ask-become-pass

# Restart services
sudo systemctl restart landscape-api landscape-appserver landscape-msgserver
```

### Users can't access after login

**Problem:** User logs in but has no permissions.

**Solution:**
1. In Landscape web UI, go to **Settings** → **Users**
2. Find the Azure AD user (will have their email as username)
3. Assign appropriate roles/permissions
4. Consider creating a default role for new Azure AD users

## Security Best Practices

### 1. Secret Rotation

- Client secrets expire - note the expiration date
- Rotate secrets before expiration (set calendar reminder)
- When rotating:
  1. Create new secret in Azure (don't delete old one yet)
  2. Update Landscape configuration with new secret
  3. Test login
  4. Delete old secret in Azure

### 2. Use HTTPS

- OAuth should always use HTTPS in production
- If using HTTP (like `http://10.10.7.242`), only for internal testing
- Configure SSL certificate for production:
  ```yaml
  landscape_ssl_cert: "/etc/ssl/certs/landscape.crt"
  landscape_ssl_key: "/etc/ssl/private/landscape.key"
  ```

### 3. Restrict App Registration

- Use **Single tenant** for internal-only access
- Regularly review API permissions
- Use least-privilege principle for Graph API permissions

### 4. Monitor Access

- Review Azure AD sign-in logs regularly
- Enable conditional access policies if needed
- Monitor Landscape audit logs for user activity

## Configuration Reference

### Vault Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `landscape_oidc_issuer` | Azure AD token issuer URL | `https://login.microsoftonline.com/{TENANT_ID}/v2.0/` |
| `landscape_oidc_client_id` | Application (client) ID from Azure | `a513c06b-f481-4e4e-8e8a-c7321eb51574` |
| `landscape_oidc_client_secret` | Client secret value from Azure | `Zgn8Q~AbCdEf...` |

### Landscape Configuration File

Location: `/etc/landscape/service.conf`

```ini
[landscape]
# ... other configuration ...

# Azure AD OAuth Configuration
oidc-issuer = https://login.microsoftonline.com/08b1bea8-9892-428f-b3a9-032db07ed2ce/v2.0/
oidc-client-id = a513c06b-f481-4e4e-8e8a-c7321eb51574
oidc-client-secret = Zgn8Q~AbCdEfGhIjKlMnOpQrStUvWxYz0123456
```

## Next Steps

1. **Set up user roles:** Configure default permissions for Azure AD users
2. **Test with multiple users:** Verify different users can authenticate
3. **Configure conditional access:** Use Azure AD policies if needed
4. **Document for users:** Create internal docs on how employees should log in

## Related Documentation

- [Azure AD App Registration Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Landscape Server Documentation](roles/svwi-landscape/README.md)
- [OAuth 2.0 / OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)

## Support

For issues specific to:
- **Azure AD configuration:** Contact your Azure/Microsoft 365 administrator
- **Landscape server configuration:** Check Landscape logs at `/var/log/landscape/`
- **Ansible deployment:** Review playbook output and check connectivity to landscape server
