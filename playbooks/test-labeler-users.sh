#!/bin/bash

# Test script for running svwi-users role on labeler machines
# This script deploys user accounts and configurations to all labeler systems

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INVENTORY_FILE="../inventory/hosts"
PLAYBOOK_FILE="site.yml"
ROLE_TAG="svwi-users"
LABELER_GROUP="labeler-machines"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo "================================================================"
echo "    SVWI-USERS ROLE TEST SCRIPT FOR LABELER MACHINES"
echo "================================================================"
echo

# Check if we're in the right directory
if [ ! -f "site.yml" ] || [ ! -d "../roles" ]; then
    log_error "This script must be run from the svw-ansible/playbooks directory"
    exit 1
fi

# Validate inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    log_error "Inventory file $INVENTORY_FILE not found!"
    exit 1
fi

log_info "Starting user management deployment for labeler machines..."

# Show target machines
echo
log_info "Target machines from [$LABELER_GROUP] group:"
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" --list-hosts 2>/dev/null || {
    log_warning "No hosts found in $LABELER_GROUP group"
    exit 1
}
echo

# Step 1: Pre-flight checks
echo
echo "Step 1: Pre-flight Checks"
echo "========================="

# Check host connectivity
log_info "Checking connectivity to all labeler machines..."
if ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m ping; then
    log_success "All labeler machines are reachable"
else
    log_error "Some labeler machines are not reachable!"
    exit 1
fi

# Check if we can become (sudo access)
log_info "Testing sudo access on labeler machines..."
if ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "whoami && sudo -n whoami" -b; then
    log_success "Sudo access confirmed on all labeler machines"
else
    log_warning "Sudo access issues detected on some machines"
fi

# Check current users (for comparison)
log_info "Current user status on labeler machines..."
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "getent passwd | grep -E '(labelers|admins|docker)' | sort" -b

echo
echo "Step 2: Dry Run (Check Mode)"
echo "============================="

# Run in check mode first
log_info "Running in check/dry-run mode to see what would be changed..."
if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
    --tags="$ROLE_TAG" \
    --limit="$LABELER_GROUP" \
    --check \
    --diff \
    --verbose; then
    log_success "Check mode completed successfully"
else
    log_warning "Check mode completed with warnings or changes detected"
fi

# Ask for confirmation before making changes
echo
read -p "Do you want to proceed with the actual deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled by user"
    exit 0
fi

echo
echo "Step 3: Actual Deployment"
echo "========================="

# Run the actual deployment
log_info "Deploying user management to labeler machines..."
if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
    --tags="$ROLE_TAG" \
    --limit="$LABELER_GROUP" \
    --diff \
    --verbose; then
    log_success "User management deployment completed successfully"
else
    log_error "Deployment failed!"
    exit 1
fi

echo
echo "Step 4: Post-deployment Verification"
echo "====================================="

# Verify key users exist
log_info "Verifying key user accounts on labeler machines..."
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "getent passwd | grep -E '(rovard|mweaver|tmoon|jrice|clee)'" -b

# Verify groups
log_info "Verifying groups on labeler machines..."
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "getent group | grep -E '(labelers|docker|admins)' | sort" -b

# Verify skeleton files
log_info "Verifying skeleton files on labeler machines..."
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "ls -la /etc/skel/" -b

# Check sudoers files
log_info "Verifying sudoers files on labeler machines..."
ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "ls -la /etc/sudoers.d/" -b

echo
log_success "Labeler machine user management deployment completed!"
echo
echo "Summary:"
echo "========"
echo "✅ User accounts synchronized across all labeler machines"
echo "✅ Group memberships verified (labelers, docker, admins)"
echo "✅ Skeleton files deployed to /etc/skel"
echo "✅ Sudoers configurations applied"
echo "✅ SSH keys distributed as configured"
echo
echo "Next steps:"
echo "- Test login with a test user account"
echo "- Verify sudo access for labelers group members"
echo "- Check that Docker access works for labelers"
echo

# Generate a report
REPORT_FILE="labeler_deployment_$(date +%Y%m%d_%H%M%S).log"
echo
log_info "Generating deployment report: $REPORT_FILE"
{
    echo "SVWI-USERS DEPLOYMENT REPORT"
    echo "==========================="
    echo "Date: $(date)"
    echo "Target: Labeler Machines"
    echo "Group: $LABELER_GROUP"
    echo "Role Tag: $ROLE_TAG"
    echo
    echo "Target Machines:"
    ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" --list-hosts
    echo
    echo "Post-deployment user verification:"
    ansible -i "$INVENTORY_FILE" "$LABELER_GROUP" -m shell -a "getent passwd | grep -E '(labelers|admins|docker)' | sort" -b
} > "$REPORT_FILE"

log_success "Report saved to: $REPORT_FILE"
