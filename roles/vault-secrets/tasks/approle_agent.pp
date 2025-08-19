- name: Ensure the /run/vault-<name> directory exists
  ansible.builtin.file:
    path: /run/vault-vault
    state: directory
    owner: vault
    group: hashicorp
    mode: '0750'

- name: Ensure the Vault agent configuration directory exists
  ansible.builtin.copy:
    path: "/etc/tmpfiles.d/{{ title }}_vault-agent.conf"
    content: |
       # Create directories used by the Vault agent
       #Type Path          Mode  UID   GID       Age Argument
       d!    /run/vault    0700  root  root      -
       d!    /run/vault-${owner} 0710  ${owner}  hashicorp  -
    state: present
  notify:
    - systemd daemon-reload

- name: Ensure vault approle id file exists
  
    file { default:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['/etc/vault'],
      ;
      $approle_id_file:
        content => Sensitive($role_id),
      ;
      $approle_secret_file:
        content => Sensitive($secret_id),
      ;
    }

    if $local_listener {
      $agent_conf = {
        exit_after_auth => false,
        pid_file        => "/run/vault/${title}_vault-agent.pid",
        vault           => { address => $vault_addr, },
        auto_auth       => {
          method       => {
            type       => 'approle',
            mount_path => 'auth/approle',
            config     => {
              role_id_file_path                   => $approle_id_file,
              secret_id_file_path                 => $approle_secret_file,
              remove_secret_id_file_after_reading => false,
            },
          },
          sinks         => [
            sink   => {
              type   => file,
              config => { path => $sink_file, },
            },
          ],
        },
        cache => {
          use_auto_auth_token => true
        },
          listener => {
            type => 'tcp',
            address => '127.0.0.1:8100',
            tls_disable => true
        }
      }
    } else {
    # Define the AppRole configuration for Vault agent
    $agent_conf = {
      exit_after_auth => false,
      pid_file        => "/run/vault/${title}_vault-agent.pid",
      vault           => { address => $vault_addr, },
      auto_auth       => {
        method       => {
          type       => 'approle',
          mount_path => 'auth/approle',
          config     => {
            role_id_file_path                   => $approle_id_file,
            secret_id_file_path                 => $approle_secret_file,
            remove_secret_id_file_after_reading => false,
          },
        },
        sinks         => [
          sink   => {
            type   => file,
            config => { path => $sink_file, },
          },
        ],
      }
    }
    }


    if $filename != '' {
      $agent_config_file = "/etc/vault/${title}_agent.hcl"
      file { $agent_config_file:
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        require => File['/etc/vault'],
        notify  => Service["${title}-vault-agent.service"],
        content => template("vault_secrets/${filename}.erb"),
      }
    } else {
      $agent_config_file = "/etc/vault/${title}_agent.json"
      file { $agent_config_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => File['/etc/vault'],
      notify  => Service["${title}-vault-agent.service"],
      content => to_json_pretty($agent_conf),
    }
    }

    systemd::unit_file { "${title}-vault-agent.service":
      enable  => true,
      active  => true,
      require => File['/run/vault'],
      content => @("END"/$),
                 # FILE MANAGED BY PUPPET
                 [Unit]
                 Description=Vault agent - ${title}
                 Wants=${title}-vault-token.path
                 
                 [Service]
                 PIDFile=/run/vault/vault-agent.pid
                 ExecStart=/usr/bin/vault agent -config=${$agent_config_file}
                 ExecReload=/bin/kill -HUP \$MAINPID
                 KillMode=process
                 KillSignal=SIGTERM
                 Restart=on-failure
                 RestartSec=42s
                 LimitMEMLOCK=infinity
                 
                 [Install]
                 WantedBy=multi-user.target
                 |END
    }

    systemd::unit_file { "${title}-vault-token.service":
      enable  => true,
      content => @("END"),
                 # FILE MANAGED BY PUPPET
                 [Service]
                 Type=oneshot
                 ExecStart=/bin/chown ${owner}:hashicorp ${sink_file}
                 |END
    }

    if $pushsink {
      systemd::unit_file { "${title}-push-vault-token.service":
        enable  => true,
        content => @("END"),
                  # FILE MANAGED BY PUPPET
                  [Service]
                  Type=oneshot
                  ExecStart=/bin/bash /opt/nomad/${title}-push-vault-token.sh -f ${sink_file}
                  |END
      }

      systemd::unit_file { "${title}-push-vault-token.path":
        enable  => true,
        active  => true,
        content => @("END"),
                  # FILE MANAGED BY PUPPET
                  [Unit]
                  Description=Monitor Vault token file to push
                  Wants=network.target network-online.target
                  After=network.target network-online.target
                  
                  [Path]
                  PathChanged=${sink_file}
                  Unit=${title}-push-vault-token.service
                  |END
      }
    }

    systemd::unit_file { "${title}-vault-token.path":
      enable  => true,
      active  => true,
      content => @("END"),
                # FILE MANAGED BY PUPPET
                [Unit]
                Description=Monitor Vault token file
                Wants=network.target network-online.target
                After=network.target network-online.target
                
                [Path]
                PathChanged=${sink_file}
                Unit=${title}-vault-token.service
                |END
    }

    # END ensure => 'present'
  } else {
    systemd::tmpfile { "${title}_vault-agent.conf":
      ensure => 'absent',
    }

    file { [$sink_file, $approle_id_file, $approle_secret_file, $agent_config_file]:
      ensure  => 'absent',
      require => [
        Systemd::Unit_file["${title}-vault-agent.service"],
        Systemd::Unit_file["${title}-vault-token.service"],
        Systemd::Unit_file["${title}-vault-token.path"],
      ],
    }

    systemd::unit_file { [
        "${title}-vault-agent.service",
        "${title}-vault-token.service",
        "${title}-vault-token.path",
      ]:
      ensure => 'absent',
    }
  }
}

