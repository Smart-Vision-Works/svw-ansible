#!/bin/bash
# Create Landscape configuration on the server
# Run this ON the landscape server (10.10.7.242)

cat > /etc/landscape/service.conf << 'EOF'
[landscape]
# Database connections
store = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-main
account-1 = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-account-1
package = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-package
resource-1 = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-resource-1
session = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-session
knowledge = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-knowledge

# Message system
message-system = rabbit
message-system-host = localhost

# Web interface
http-port = 8080
https-port = 8443

# Log settings
log-dir = /var/log/landscape
log-level = info

# Package repository
package-path = /var/lib/landscape/package

[schema]
# Schema configuration (required for schema upgrades)
store = postgres://landscape_superuser:CHANGE_PASSWORD@localhost/landscape-standalone-main
EOF

echo ""
echo "Configuration created at /etc/landscape/service.conf"
echo ""
echo "IMPORTANT: You need to edit this file and replace CHANGE_PASSWORD with the actual password!"
echo ""
echo "Run: nano /etc/landscape/service.conf"
echo "Replace all instances of CHANGE_PASSWORD with the landscape_superuser password from vault.yml"
