#!/bin/bash
# Reconnect Landscape Client to New Server
# This script reconfigures a landscape client to connect to a new Landscape server
# Use this when migrating from an old (deleted) server to a new server instance

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 <server_url> <account_name> <registration_key> [options]

Reconnects a Landscape client to a new server by removing old configuration
and registering with the new server.

Arguments:
  server_url         URL or IP of new Landscape server (e.g., lds.svwi.us or 10.10.7.242)
  account_name       Landscape account name (e.g., "Smart Vision Works")
  registration_key   Registration key from Landscape server

Options:
  --insecure         Use HTTP instead of HTTPS (for servers without SSL)
  --computer-title   Custom computer title (default: hostname)
  --tags            Comma-separated tags (e.g., "production,webserver")
  --help            Show this help message

Examples:
  # HTTPS server with domain name
  $0 lds.svwi.us "Smart Vision Works" "YOUR_KEY_HERE"

  # HTTP server with IP address (no SSL)
  $0 10.10.7.242 "Default" "YOUR_KEY_HERE" --insecure

  # With custom title and tags
  $0 lds.svwi.us "Smart Vision Works" "KEY" --computer-title "web-server-01" --tags "production,webserver"

EOF
    exit 1
}

# Check for help flag
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
fi

# Check minimum arguments
if [ $# -lt 3 ]; then
    print_error "Missing required arguments"
    usage
fi

# Parse arguments
SERVER_URL="$1"
ACCOUNT_NAME="$2"
REGISTRATION_KEY="$3"
shift 3

# Default options
USE_HTTPS="yes"
COMPUTER_TITLE="$(hostname)"
TAGS=""

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --insecure)
            USE_HTTPS="no"
            shift
            ;;
        --computer-title)
            COMPUTER_TITLE="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Construct URLs based on HTTPS/HTTP
if [ "$USE_HTTPS" == "yes" ]; then
    PROTOCOL="https"
    print_info "Using HTTPS (secure)"
else
    PROTOCOL="http"
    print_warn "Using HTTP (insecure) - only use this for internal testing!"
fi

MESSAGE_URL="${PROTOCOL}://${SERVER_URL}/message-system"
PING_URL="${PROTOCOL}://${SERVER_URL}/ping"

echo "=========================================="
echo "Landscape Client Reconnection Script"
echo "=========================================="
echo ""
print_info "Configuration:"
echo "  Server URL:      ${SERVER_URL}"
echo "  Account Name:    ${ACCOUNT_NAME}"
echo "  Computer Title:  ${COMPUTER_TITLE}"
echo "  Message URL:     ${MESSAGE_URL}"
echo "  Ping URL:        ${PING_URL}"
if [ -n "$TAGS" ]; then
    echo "  Tags:            ${TAGS}"
fi
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if landscape-client is installed
if ! command -v landscape-config &> /dev/null; then
    print_error "landscape-client is not installed"
    print_info "Install with: sudo apt install landscape-client"
    exit 1
fi

# Step 1: Stop landscape-client service
print_info "Step 1: Stopping landscape-client service..."
systemctl stop landscape-client || print_warn "Service was not running"
sleep 2

# Step 2: Backup old configuration (if it exists)
print_info "Step 2: Backing up old configuration..."
if [ -f /etc/landscape/client.conf ]; then
    BACKUP_DIR="/root/landscape-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp /etc/landscape/client.conf "$BACKUP_DIR/" 2>/dev/null || true
    print_info "Old config backed up to: ${BACKUP_DIR}"
fi

# Step 3: Remove old client configuration
print_info "Step 3: Removing old client configuration..."
rm -f /etc/landscape/client.conf
rm -f /etc/landscape/client.conf.old
print_info "Removed old configuration files"

# Step 4: Remove old SSL certificates
print_info "Step 4: Removing old SSL certificates..."
rm -f /etc/landscape/*.pem
rm -f /etc/landscape/*.crt
print_info "Removed old certificates"

# Step 5: Clear client state
print_info "Step 5: Clearing client state..."
rm -rf /var/lib/landscape/client/*
print_info "Cleared client state directory"

# Step 6: Configure client with new server
print_info "Step 6: Configuring client for new server..."

# Build landscape-config command
CONFIG_CMD="landscape-config"
CONFIG_CMD="$CONFIG_CMD --computer-title \"${COMPUTER_TITLE}\""
CONFIG_CMD="$CONFIG_CMD --account-name \"${ACCOUNT_NAME}\""
CONFIG_CMD="$CONFIG_CMD --url \"${MESSAGE_URL}\""
CONFIG_CMD="$CONFIG_CMD --ping-url \"${PING_URL}\""
CONFIG_CMD="$CONFIG_CMD --registration-key \"${REGISTRATION_KEY}\""

# Add tags if specified
if [ -n "$TAGS" ]; then
    CONFIG_CMD="$CONFIG_CMD --tags \"${TAGS}\""
fi

# Add SSL verification flag for insecure connections
if [ "$USE_HTTPS" == "no" ]; then
    CONFIG_CMD="$CONFIG_CMD --ssl-public-key-file=/dev/null"
fi

CONFIG_CMD="$CONFIG_CMD --silent"

# Execute configuration
print_info "Running: landscape-config [arguments hidden for security]"
eval $CONFIG_CMD

if [ $? -eq 0 ]; then
    print_info "Client configuration successful"
else
    print_error "Client configuration failed"
    exit 1
fi

# Step 7: Start landscape-client service
print_info "Step 7: Starting landscape-client service..."
systemctl start landscape-client

sleep 3

# Step 8: Verify service is running
print_info "Step 8: Verifying service status..."
if systemctl is-active --quiet landscape-client; then
    print_info "✓ landscape-client service is running"
else
    print_error "✗ landscape-client service failed to start"
    print_info "Checking logs..."
    journalctl -u landscape-client -n 20 --no-pager
    exit 1
fi

# Step 9: Check registration status
print_info "Step 9: Checking registration status..."
sleep 5  # Give client time to connect

# Try to get client info
if landscape-client --is-registered &> /dev/null; then
    print_info "✓ Client successfully registered with server"
else
    print_warn "⚠ Client may still be registering (this can take a few minutes)"
    print_info "Check status with: sudo landscape-client --is-registered"
fi

# Step 10: Show client log
print_info "Step 10: Recent client logs:"
echo "----------------------------------------"
tail -15 /var/log/landscape/client.log 2>/dev/null || print_warn "Could not read client log"
echo "----------------------------------------"

echo ""
echo "=========================================="
print_info "Reconnection process completed!"
echo "=========================================="
echo ""
print_info "Summary:"
echo "  - Old configuration removed"
echo "  - Client reconfigured for: ${SERVER_URL}"
echo "  - Service restarted"
echo ""
print_info "Next steps:"
echo "  1. Wait 2-3 minutes for initial sync"
echo "  2. Check registration: sudo landscape-client --is-registered"
echo "  3. View in Landscape UI: ${PROTOCOL}://${SERVER_URL}"
echo "  4. Check logs: tail -f /var/log/landscape/client.log"
echo ""
print_info "Useful commands:"
echo "  - Check service: systemctl status landscape-client"
echo "  - Check registration: sudo landscape-client --is-registered"
echo "  - Force sync: sudo landscape-client --config-file=/etc/landscape/client.conf"
echo "  - View logs: tail -f /var/log/landscape/client.log"
echo ""

# Exit successfully
exit 0
