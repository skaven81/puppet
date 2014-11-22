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

# Add a few more authorized keys
ssh_authorized_key { 'galaxy_note_4@aws':
    user    => 'ec2-user',
    key     => $::pubkeys::galaxy_note_4,
    type    => $::pubkeys::galaxy_note_4_type,
}


