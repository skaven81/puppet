# This manifest is for configuring
# the AWS instance that hosts a
# simple web server.

include ::pubkeys

account {'ec2-user':
    ensure  => 'present',
    uid     => 1000,
    shell   => '/bin/bash',
    manage_home => true,
    create_group => true,
    groups  => [ 'adm', 'wheel', 'systemd-journal' ],
    ssh_key => $::pubkeys::aws,
    ssh_key_type => $::pubkeys::aws_type,
    purge_ssh_keys => true,
    comment => 'AWS-provided login',
}

# Add a few more authorized keys
ssh_authorized_key { 'galaxy_note_4@aws':
    user    => 'ec2-user',
    key     => $::pubkeys::galaxy_note_4,
    type    => $::pubkeys::galaxy_note_4_type,
}
ssh_authorized_key { 'token@aws':
    user    => 'ec2-user',
    key     => $::pubkeys::token,
    type    => $::pubkeys::token_type,
}

# Packages
Package {
    allow_virtual => true,
}
package { [ 'puppet' ]:
    ensure  => 'latest',
}

# Extra volumes
mount { '/var/www/html/www.rainbowlakeestate.net':
    # AWS volume id vol-ff6ce8e7j
    device  => 'UUID=b06d95ee-9ca7-4cc1-a79b-1cb26f4f9c09',
    ensure  => 'mounted',
    atboot  => true,
    fstype  => 'xfs',
    #options => 'ro,noatime',
}
            
# Apache configuration
class { 'apache':
    default_confd_files => false,
    default_mods        => false,
    default_vhost       => false,
    package_ensure      => 'present',
    service_ensure      => 'running',
    server_signature    => 'Off',
    trace_enable        => 'Off',
}
class { 'apache::mod::dir': }
apache::vhost { 'main':
    port           => 80,
    docroot        => '/var/www/html',
    directoryindex => 'index.html index.htm',
}
