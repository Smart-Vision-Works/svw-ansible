# This denotes the start of the configuration section for Vault. All values
# contained in this section pertain to Vault.
vault {
  # This is the address of the Vault leader. The protocol (http(s)) portion
  # of the address is required.
  address      = "http://127.0.0.1:8100"

  # This value can also be specified via the environment variable VAULT_TOKEN.
  # vault_agent_token_file = "<%= @vaultlocaltoken %>"

  unwrap_token = false

  renew_token  = false
}

consul {
  address = "https://127.0.0.1:8501"
}

template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  source      = "/opt/consul/templates/snapshot-token.tpl"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "/etc/vault.d/snapshots.token"

  # This is the permission to render the file. If this option is left
  # unspecified, consul-template will attempt to match the permissions of the
  # file that already exists at the destination path. If no file exists at that
  # path, the permissions are 0644.
  perms       = 0640
}

template {
  # This is the source file on disk to use as the input template. This is often
  # called the "consul-template template".
  source      = "/opt/consul/templates/gcpckms.tpl"

  # This is the destination path on disk where the source template will render.
  # If the parent directories do not exist, consul-template will attempt to
  # create them, unless create_dest_dirs is false.
  destination = "/etc/vault.d/gcpckms.json"

  # This is the permission to render the file. If this option is left
  # unspecified, consul-template will attempt to match the permissions of the
  # file that already exists at the destination path. If no file exists at that
  # path, the permissions are 0644.
  perms       = 0640

  command = "/usr/bin/systemctl restart vault"
}

log_file {
  # If a path is specified, the feature is enabled
  # Please refer to the documentation for the -log-file
  # CLI flag for more information about its behaviour
  path = "/var/log/consul/consul-template.log"

  # This allow you to control the number of bytes that
  # should be written to a log before it needs to be
  # rotated. Unless specified, there is no limit to the
  # number of bytes that can be written to a log file

  # This lets you control time based rotation, by default
  # logs are rotated every 24h
  log_rotate_duration = "24h"

  # This lets you control the maximum number of older log
  # file archives to keep. Defaults to 0 (no files are ever
  # deleted).
  # Set to -1 to discard old log files when a new one is
  # created
  log_rotate_max_files = 10
}
