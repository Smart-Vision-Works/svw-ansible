# svwi-office-blade

Ansible role for configuring office blade servers. This role was translated from the Puppet module `svwi_office_blade`.

## Description

This role configures a blade server in the office for local applications, including:
- Docker registry and proxy services
- APT cache proxy (apt-cacher-ng)
- DNS services (via svwi-dns role)
- PXE/TFTP boot services (dnsmasq)
- Device status monitoring

## Requirements

- Ansible 2.9+
- `community.docker` collection
- Docker must be installed on the target system
- The `svwi-dns` and `svwi-users` roles must be available

## Role Variables

Variables are defined in `defaults/main.yml`:

### Vault-managed secrets
These should be defined in your vault configuration:
- `aptcachepw`: Password for apt-cacher-ng authentication
- `labelingdockertoken`: Docker token for labeling registry
- `balenatoken`: Balena.io API token
- `mongoapipubkey`: MongoDB API public key
- `mongoapiprivkey`: MongoDB API private key
- `mongopassword`: MongoDB password

### DNS configuration
- `dns_buddyip`: '10.10.1.1'
- `dns_dnshostname`: 'nsoffice.svwi.us'
- `dns_sqlid`: '103'

### Docker configuration
- `docker_insecure_registries`: List of insecure Docker registries
- `proxpi_version`: Version tag for proxpi image (default: 'v1.1.0')
- `registry_version`: Version tag for Docker registry image (default: 'latest')
- `device_status_image`: Device status Docker image name
- `device_status_tag`: Device status Docker image tag

### MongoDB configuration
- `mongo_protocol`: 'mongodb+srv://'
- `mongo_host`: MongoDB connection host string
- `mongo_username`: MongoDB username

## Dependencies

- `svwi-dns`: DNS server configuration
- `svwi-users`: User management

## Example Playbook

```yaml
- hosts: office_blades
  roles:
    - role: svwi-office-blade
      vars:
        dns_buddyip: '10.10.1.1'
        dns_dnshostname: 'nsoffice.svwi.us'
```

## Tags

- `users`: User management tasks
- `packages`: Package installation
- `dns`: DNS configuration
- `directories`: Directory creation
- `docker`: Docker configuration and containers
- `apt-cacher`: APT cacher configuration
- `dnsmasq`: DNSMasq configuration
- `systemd`: Systemd unit configuration
- `device-status`: Device status monitoring
- `cron`: Cron job management

## Notes

### Translation from Puppet

This role was translated from the Puppet module located at `puppet/site-modules/svwi_office_blade`. Key changes:

1. **Docker module**: Puppet's `docker::run` and `docker::image` were translated to `community.docker.docker_container` and `community.docker.docker_image`
2. **Templates**: EPP and ERB templates converted to Jinja2
3. **apt-cacher-ng**: Puppet class converted to manual apt installation and configuration
4. **Handlers**: Service restarts moved to handlers for idempotency
5. **State management**: `ensure => absent` translated to `state: absent`

### Services

The following services are configured but **disabled** by default:
- `dnsmasq`: PXE boot service (stopped and disabled)
- `anritsu-ftp`: FTP server for Anritsu images (stopped and disabled)

The following Docker containers are **running**:
- `registry`: Docker registry on port 5555
- `epicwink-proxpi`: Python package proxy on port 5000

### Commented Features

The NFS mount for apt-cacher-ng cache is commented out in both the original Puppet code and this Ansible role. To enable it, uncomment the task in `tasks/main.yml` and ensure the `ansible.posix` collection is installed.

## License

Proprietary - Smart Vision Works / KPM Analytics

## Author

Translated from Puppet by DevOps team, 2025
