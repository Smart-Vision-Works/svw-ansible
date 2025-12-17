# svwi-datarig

Ansible role for configuring data rig servers (training/ML workstations). This role was translated from the Puppet module `svwi_datarig`.

## Description

This role configures GPU-enabled data rig servers for machine learning and data processing workloads, including:
- NVIDIA drivers and NVIDIA Docker support
- Docker with GPU runtime configuration
- Vector logging to BetterStack
- NFS mounts for shared storage
- SSH with Boundary credential injection
- Google Cloud SDK
- System tuning (swappiness, kernel modules)
- User management for data team and admins

## Requirements

- Ansible 2.9+
- `community.general` collection
- `community.docker` collection
- `ansible.posix` collection
- `geerlingguy.docker` role (automatically included)
- NVIDIA GPU hardware
- The `svwi-basenode` and `svwi-users` roles must be available

## Role Variables

Variables are defined in `defaults/main.yml`:

### Vault-managed secrets (per-host)
These should be defined in your vault configuration or host_vars:
- `betterlog`: BetterStack logging token
- `betterlog_host`: BetterStack logging host
- `betterlog_data_team_docker`: BetterStack token for Docker logs
- `betterlog_data_team_docker_host`: BetterStack host for Docker metrics

### NFS Configuration
- `nfs_server`: '10.10.1.50'
- `nfs_share`: '/mnt/tank/shared'
- `nfs_mount_point`: '/auto/shared'

### System Configuration
- `vm_swappiness`: '10' (reduced from default 60 for systems with large RAM)
- `nvidia_driver_version`: '550-server'
- `nuctl_version`: '1.8.14'

### Docker Configuration
- `docker_insecure_registries`: List of insecure Docker registries
  - 10.10.4.5:5003
  - 10.10.4.6:5003
  - 10.8.7.248:5555

### Kernel Modules
- `kernel_modules`: ['bridge', 'br_netfilter']

### Package Management
- `packages_to_remove`: Packages to uninstall (nomad, consul, zabbix, etc.)
- `packages_to_install`: Required packages (nvidia drivers, nfs-common, libteam-utils)

## Dependencies

- `svwi-basenode`: Base node configuration
- `svwi-users`: User management (admins, data, service)
- `geerlingguy.docker`: Docker installation

## Example Playbook

```yaml
- hosts: datarig_servers
  roles:
    - role: svwi-datarig
      vars:
        betterlog: "{{ vault.betterlog }}"
        betterlog_host: "{{ vault.betterlog_host }}"
```

## Tags

- `kernel`: Kernel module management
- `docker`: Docker installation and configuration
- `packages`: Package installation/removal
- `services`: Service management
- `users`: User configuration
- `nfs`: NFS mount configuration
- `sysctl`: Sysctl tuning
- `nvidia`: NVIDIA driver and container toolkit
- `gcloud`: Google Cloud SDK
- `nuctl`: Nuclio CLI tool
- `ssh`: SSH/Boundary configuration
- `vector`: Vector logging agent
- `scripts`: Shell scripts
- `cron`: Cron job management

## Translation from Puppet

This role was translated from the Puppet module located at `puppet/site-modules/svwi_datarig`. Key changes:

1. **Role inclusion**: Puppet's `include` statements converted to `include_role`
2. **Package management**: `package` resource converted to `apt` module
3. **Archive downloads**: Puppet `archive` resource converted to `get_url` + `shell` for GPG key handling
4. **Docker**: Using `geerlingguy.docker` role instead of custom Puppet module
5. **Templates**: ERB template converted to Jinja2
6. **Service management**: Puppet `service` converted to `systemd` module
7. **Kernel modules**: Puppet `kmod::load` converted to `community.general.modprobe`
8. **Mounts**: Puppet `mount` converted to `ansible.posix.mount`
9. **Sysctl**: Puppet `sysctl` converted to `ansible.posix.sysctl`

### Services

The following services are **running and enabled**:
- `docker`: Docker daemon with NVIDIA runtime
- `vector`: Logging agent
- `ssh`: SSH server with Boundary support

The following services are **stopped and disabled**:
- `nomad`: Removed (workloads no longer run via Nomad)
- `consul`: Removed (service discovery no longer needed)
- `zabbix-agent2`: Removed (monitoring migrated to BetterStack)
- `zabbix-agent`: Removed (monitoring migrated to BetterStack)

### Files

Static files copied from Puppet module:
- `docker-daemon.json`: Docker daemon configuration with NVIDIA runtime and insecure registries
- `boundary-ca.pub`: Boundary CA public key for SSH credential injection
- `boundary.conf`: SSH configuration for Boundary
- `data-install-security-updates.sh`: Security update script (disabled via cron)

### Removed from Original Puppet

The following were present in Puppet but removed in Ansible:
- GCR token authentication (no longer needed)
- Commented-out vector docker group addition (now active)
- Various Zabbix configurations (monitoring migrated)

## Hosts

This role is applied to the following hosts (from `puppet/manifests/nodes.pp`):
- viki.svwi.us
- eureka.svwi.us
- singularity.svwi.us

## License

Proprietary - Smart Vision Works / KPM Analytics

## Author

Translated from Puppet by DevOps team, 2025
