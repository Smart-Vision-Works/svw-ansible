Here is a list of puppet modules that need to be transcribed from
`../puppet/site-modules` to `./roles/` as ansible roles:

- svwi_users
  - [x] code up
  - [x] finish testing
- svwi_basenode
  - [x] code up
  - [x] finish testing
- svwi_vault
  - [ ] code up
  - [ ] finish testing
- svwi_datarig
  - [ ] code up
  - [ ] finish testing
- svwi_dcblade (not the parts that create VMs with multipass though, just basic config, no VM spinning up)
  - [ ] code up
  - [ ] finish testing
- svwi_dns class
  - [ ] code up
  - [ ] finish testing
- svwi_labelers
  - [ ] code up
  - [ ] finish testing
- svwi_office_blade
  - [ ] code up
  - [ ] finish testing
- ca_cert
  - [ ] code up
  - [ ] finish testing
- svwi_certs
  - [ ] code up
  - [ ] finish testing
- landscape
  - [ ] code up
  - [ ] finish testing
- vault_loadbalancer
  - [ ] code up
  - [ ] finish testing

These roles then need to be included in the `tasks/all-tasks.yml` task file.

Please keep the above checklist up-to-date.

We note that not all puppet modules in `site-modules` need to be transcribed,
as many of them are now obsolete. Only those listed above need transcribed.
Please get them migrated in the order that they appear in the list.

To test the code changes, I have simply been running `ansible-playbook
site.yml` from the top-level directory of this repository.

In doing so, we note that the `lookup()` puppet function was used to look up
secrets in a Hashicorp Vault instance. When you come across these, ask me what
the value was and use `ansible-vault` to edit/add entries in `vault.yml` when
transcribing secrets.

Go.

NOTE: Ignore any Puppet configurations related to 'Vector' for logging. We no
longer use it.
NOTE: Ignore any Puppet configurations related to 'Consul'. We no longer use it.