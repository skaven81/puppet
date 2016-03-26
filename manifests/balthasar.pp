# This manifest is for configuring
# the AWS instance that hosts a
# simple web server.

include ::pubkeys

group { 'www':
    ensure  => 'present',
    gid     => 1010,
} ->
account {'ec2-user':
    ensure  => 'present',
    uid     => 500,
    shell   => '/bin/bash',
    manage_home => true,
    create_group => true,
    groups  => [ 'wheel' ],
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
package { [ 'puppet' ]:
    ensure  => 'latest',
}

# Extra volumes
define http_mount (
    $path = $title,
    $uuid = undef,
    $ensure = 'present',
) {
    file { $path:
        ensure  => 'directory',
        owner   => 'root',
        group   => 'root',
        seluser => 'unconfined_u',
        selrole => 'object_r',
        seltype => 'httpd_sys_content_t',
        recurse => true,
    } -> 
    mount { $path:
        device  => "UUID=${uuid}",
        ensure  => $ensure,
        atboot  => true,
        fstype  => 'xfs',
        options => 'noatime',
    }
}

http_mount { '/var/www/html/www.counterstonecreations.com':
    # AWS volume id vol-1a0b8f02
    uuid => '01ddb84c-0c3b-4408-81fe-37457b83ddc3',
}

# "MyIP" site
file { '/var/www/html/myip':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    seluser => 'unconfined_u',
    selrole => 'object_r',
    seltype => 'httpd_sys_content_t',
    recurse => 'true',
} ->
file { '/var/www/html/myip/index.php':
    ensure => 'file',
    owner   => 'root',
    group   => 'root',
    seluser => 'unconfined_u',
    selrole => 'object_r',
    seltype => 'httpd_sys_content_t',
    content => template('myip/index.php'),
}
            
# Apache configuration
class { 'apache':
    default_confd_files => false,
    default_mods        => false,
    default_vhost       => true,
    default_ssl_vhost   => true,
    package_ensure      => 'present',
    service_ensure      => 'running',
    server_signature    => 'Off',
    trace_enable        => 'Off',
}
class { 'apache::mod::dir': }
class { 'apache::mod::php': }
Apache::Vhost <| title == 'default' |> {
    docroot        => '/var/www/html',
    directoryindex => 'index.html index.htm index.php',
}
Apache::Vhost <| title == 'default-ssl' |> {
    docroot        => '/var/www/html',
    directoryindex => 'index.html index.htm index.php',
}
