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
    ssh_key => $::pubkeys::token,
    ssh_key_type => $::pubkeys::token_type,
    comment => 'AWS-provided login',
}


