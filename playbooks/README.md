# Ansible Playbooks

This directory contains all Ansible playbooks for managing the SVW infrastructure. All playbooks should be run from this `playbooks/` directory.

## Quick Start

```bash
# Navigate to the playbooks directory
cd playbooks

# Run a playbook
ansible-playbook -i ../inventory.ini <playbook-name>.yml
```

## Available Playbooks

### 🖥️ Labeler Machines

#### `labelers.yml`
**Purpose:** NVIDIA driver updates and Docker GPU support for labeler machines  
**Target Hosts:** `labeler-machines` group  
**Key Features:**
- Installs NVIDIA driver 570+ for kernel 6.14 compatibility
- Sets up CUDA 12.8
- Configures nvidia-container-toolkit for Docker
- Includes kernel compatibility checks

**Quick Commands:**
```bash
# Test on one machine
ansible-playbook -i ../inventory.ini labelers.yml --limit svw-ls-02

# Deploy to all labelers
ansible-playbook -i ../inventory.ini labelers.yml
```

**Documentation:** See `NVIDIA_UPDATE_QUICKSTART.md` for detailed guide

---

#### `labelers-nfs.yml`
**Purpose:** Setup NFS mounts on labeler machines  
**Target Hosts:** `labeler-machines` group  
**Key Features:**
- Configures NFS mounts for `/auto/shared` and `/auto/ds`
- Verifies mount points after setup

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini labelers-nfs.yml
```

---

#### `labelers-users.yml`
**Purpose:** User account management for labeler machines  
**Target Hosts:** `labeler-machines` group  
**Key Features:**
- Creates and manages labeler user accounts
- Sets up group memberships (labelers, docker, admins)
- Configures sudoers
- Distributes SSH keys

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini labelers-users.yml
```

---

### 🌐 DNS Servers

#### `dns-servers.yml`
**Purpose:** Deploy and configure DNS servers  
**Target Hosts:** `dns-servers` group  
**Key Features:**
- Sets up DNS resolution
- Deploys svwi-dns role
- Configures base node and user accounts

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini dns-servers.yml
```

---

### 🖥️ Data Rig Servers

#### `svwi-datarig.yml`
**Purpose:** Configure data rig servers  
**Target Hosts:** `datarig_servers` group  
**Key Features:**
- Complete data rig server setup
- System configuration and dependencies
- Boundary integration

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini svwi-datarig.yml
```

---

### 🏢 Office Servers

#### `svwi-office-blade.yml`
**Purpose:** Configure office blade servers  
**Target Hosts:** `office-servers` group  
**Key Features:**
- Base node configuration
- User account management
- Office-specific setup
- DNSmasq configuration

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini svwi-office-blade.yml
```

---

### 🏢 Site-Wide

#### `site.yml`
**Purpose:** Full site compliance - ensure all systems are configured correctly  
**Target Hosts:** `all`  
**Key Features:**
- Applies base node configuration
- Manages user accounts across all systems
- Ensures IaC compliance

**Quick Commands:**
```bash
# Full site deployment
ansible-playbook -i ../inventory.ini site.yml

# Limit to specific hosts
ansible-playbook -i ../inventory.ini site.yml --limit <hostname>
```

---

### 🧪 Testing

#### `test-labeler-playbook.yml`
**Purpose:** Test svwi-users role on labeler machines  
**Target Hosts:** `labeler-machines` group  
**Key Features:**
- Verifies user accounts exist
- Checks group memberships
- Tests sudoers configuration
- Validates skeleton files

**Quick Commands:**
```bash
ansible-playbook -i ../inventory.ini test-labeler-playbook.yml
```

---

#### `test-labeler-users.sh`
**Purpose:** Interactive test script for user management on labelers  
**Features:**
- Pre-flight connectivity checks
- Dry-run mode before actual deployment
- Post-deployment verification
- Generates deployment reports

**Quick Commands:**
```bash
# Make executable if needed
chmod +x test-labeler-users.sh

# Run the test script
./test-labeler-users.sh
```

---

## Common Tasks

### Check Connectivity
```bash
ansible all -i ../inventory.ini -m ping
ansible labeler-machines -i ../inventory.ini -m ping
ansible dns-servers -i ../inventory.ini -m ping
```

### Run in Check Mode (Dry Run)
```bash
ansible-playbook -i ../inventory.ini <playbook>.yml --check --diff
```

### Limit to Specific Hosts
```bash
# Single host
ansible-playbook -i ../inventory.ini <playbook>.yml --limit svw-ls-02

# Multiple hosts
ansible-playbook -i ../inventory.ini <playbook>.yml --limit 'svw-ls-00,svw-ls-01,svw-ls-02'

# Host pattern
ansible-playbook -i ../inventory.ini <playbook>.yml --limit 'svw-ls-*'
```

### Run with Verbose Output
```bash
ansible-playbook -i ../inventory.ini <playbook>.yml -v    # verbose
ansible-playbook -i ../inventory.ini <playbook>.yml -vv   # more verbose
ansible-playbook -i ../inventory.ini <playbook>.yml -vvv  # very verbose
```

### Run Specific Tags
```bash
ansible-playbook -i ../inventory.ini site.yml --tags "nvidia"
ansible-playbook -i ../inventory.ini site.yml --tags "users,docker"
```

---

## Documentation

### 📚 Detailed Guides

- **`NVIDIA_UPDATE_QUICKSTART.md`** - Complete guide for NVIDIA driver updates
  - Deployment strategies (conservative vs aggressive)
  - Pre-flight and post-deployment checklists
  - Troubleshooting guide
  - Verification commands

- **`DEPLOYMENT_COMMANDS.md`** - Comprehensive command reference
  - Pre-deployment checks
  - Deployment options (test, rolling, all-at-once)
  - Post-deployment verification
  - Monitoring and troubleshooting

- **`NVIDIA_UPGRADE_NOTES.md`** - Technical details about NVIDIA upgrades
  - Kernel compatibility information
  - Driver version requirements
  - CUDA toolkit details

- **`CHANGES_SUMMARY.md`** - Summary of recent changes to roles and playbooks

---

## File Structure

```
playbooks/
├── README.md                       # This file
├── site.yml                        # Site-wide compliance
├── dns-servers.yml                 # DNS server deployment
├── labelers.yml                    # NVIDIA driver updates
├── labelers-nfs.yml               # NFS mount setup
├── labelers-users.yml             # User management
├── test-labeler-playbook.yml      # Testing playbook
├── test-labeler-users.sh          # Testing script
├── NVIDIA_UPDATE_QUICKSTART.md    # NVIDIA update guide
├── DEPLOYMENT_COMMANDS.md         # Command reference
├── NVIDIA_UPGRADE_NOTES.md        # Technical notes
└── CHANGES_SUMMARY.md             # Change log
```

---

## Important Notes

1. **Always run from this directory** - All playbook paths are relative to `playbooks/`
2. **Vault password required** - Ensure `../.vault.pass` exists for encrypted variables
3. **Reboot after driver updates** - NVIDIA driver changes require a reboot to take effect
4. **Test first** - Always test on one machine before rolling out to all
5. **Check mode** - Use `--check --diff` to preview changes before applying

---

## Prerequisites

- Ansible installed on control node
- SSH access to all target hosts
- Vault password file: `../.vault.pass`
- Valid inventory file: `../inventory.ini` or `../inventory/hosts`
- Proper sudo/become permissions on target hosts

---

## Getting Help

- Check the specific documentation files in this directory
- Review role documentation in `../roles/<role-name>/`
- Use `ansible-playbook --help` for command-line options
- Enable verbose mode (`-vvv`) to see detailed execution information

---

## Best Practices

1. **Always use check mode first** - Run with `--check --diff` to preview changes
2. **Test on one host** - Use `--limit` to test on a single machine first
3. **Document changes** - Update relevant documentation when modifying playbooks
4. **Use version control** - Commit changes with meaningful messages
5. **Monitor executions** - Watch for warnings and errors during playbook runs
6. **Keep backups** - Ensure critical data is backed up before major changes
7. **Schedule maintenance windows** - Notify users of planned changes/reboots


