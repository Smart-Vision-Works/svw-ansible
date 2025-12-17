# SVW Ansible Infrastructure

Ansible configuration for managing SVW infrastructure including labeler machines, DNS servers, and other systems.

## Quick Start

```bash
# Navigate to the playbooks directory
cd playbooks

# Run a playbook
ansible-playbook -i ../inventory.ini <playbook-name>.yml
```

## Directory Structure

```
svw-ansible/
├── playbooks/           # All playbooks and related documentation (START HERE!)
│   ├── README.md       # Comprehensive playbook documentation
│   ├── *.yml           # Playbook files
│   └── *.md            # Deployment guides and instructions
├── roles/              # Ansible roles
│   ├── svwi-basenode/
│   ├── svwi-dns/
│   ├── svwi-labelers/
│   ├── svwi-users/
│   └── svwi-vault/
├── inventory/          # Inventory files
├── group_vars/         # Group variables
├── host_vars/          # Host-specific variables
├── tasks/              # Shared tasks
├── ansible.cfg         # Ansible configuration
├── vault.yml           # Encrypted variables (requires vault password)
├── requirements.yml    # Ansible Galaxy requirements
└── .vault.pass         # Vault password file (not in git)
```

## Getting Started

### 1. Playbooks and Deployment

All playbooks have been organized in the `playbooks/` directory for better organization.

**See `playbooks/README.md` for:**
- Complete playbook documentation
- Deployment guides
- Common commands and tasks
- Best practices

### 2. Prerequisites

- Ansible 2.9+ installed
- SSH access to target hosts
- Vault password file (`.vault.pass`) in the root directory
- Valid inventory configuration

### 3. Available Playbooks

Navigate to `playbooks/` directory and see the README there for details on:

- **`labelers.yml`** - NVIDIA driver updates for labeler machines
- **`labelers-nfs.yml`** - NFS mount configuration
- **`labelers-users.yml`** - User account management
- **`dns-servers.yml`** - DNS server deployment
- **`site.yml`** - Site-wide compliance
- **Testing playbooks** - For validating configurations

## Quick Commands

### Check Connectivity
```bash
ansible all -i inventory.ini -m ping
```

### Run a Playbook (from playbooks/ directory)
```bash
cd playbooks
ansible-playbook -i ../inventory.ini labelers.yml --limit svw-ls-02
```

### Dry Run (Check Mode)
```bash
cd playbooks
ansible-playbook -i ../inventory.ini site.yml --check --diff
```

## Documentation

- **`playbooks/README.md`** - Main playbook documentation (start here!)
- **`playbooks/NVIDIA_UPDATE_QUICKSTART.md`** - NVIDIA driver update guide
- **`playbooks/DEPLOYMENT_COMMANDS.md`** - Command reference
- **`roles/<role-name>/`** - Individual role documentation

## Configuration Files

- **`ansible.cfg`** - Ansible configuration (inventory path, vault password, etc.)
- **`inventory.ini`** or **`inventory/hosts`** - Host inventory
- **`vault.yml`** - Encrypted sensitive variables
- **`requirements.yml`** - External role dependencies

## Roles

### svwi-basenode
Base configuration for all nodes (landscape client, certificates, etc.)

### svwi-dns
DNS server setup and configuration

### svwi-labelers
Complete labeler machine configuration including:
- NVIDIA drivers and CUDA
- Docker with GPU support
- NFS mounts
- Development tools
- GNOME desktop setup

### svwi-users
User account management across all systems

### svwi-vault
HashiCorp Vault installation and configuration

## Important Notes

1. **Run playbooks from the `playbooks/` directory**
2. **Vault password** required for accessing encrypted variables
3. **Always test first** - Use `--check` mode and `--limit` to test on one host
4. **Reboots required** - Some changes (especially driver updates) require system reboot

## Getting Help

1. Check `playbooks/README.md` for detailed playbook documentation
2. Review role-specific documentation in `roles/<role-name>/`
3. Use `ansible-playbook --help` for command options
4. Enable verbose mode with `-v`, `-vv`, or `-vvv`

## Contributing

When making changes:
1. Test on a single machine first
2. Use check mode to preview changes
3. Update relevant documentation
4. Commit with clear, descriptive messages

---

**For detailed playbook documentation and deployment guides, see: `playbooks/README.md`**


