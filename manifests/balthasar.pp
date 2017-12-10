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

cron { 'puppet-git':
    ensure  => 'present',
    user    => 'root',
    command => '/bin/bash -c "cd /opt/puppet; /usr/bin/git pull >/dev/null 2>/dev/null"',
    minute  => 0,
    hour    => 12,
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/opt/puppet/modules /opt/puppet/manifests/balthasar.pp  | grep -v "Finished catalog run"',
    minute  => 5,
    hour    => 12,
}

# Ensure LetsEncrypt certificate gets renewed
# automatically.  The certs live in /etc/letsencrypt
# and the certbot-auto utility can be used to build
# new certificates if needed.
wget::fetch { 'https://dl.eff.org/certbot-auto':
    destination => '/usr/bin/',
    timeout     => 30,
    verbose     => false,
} ->
file { '/usr/bin/certbot-auto':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0555',
} ->
cron { 'letsencrypt-renew':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/certbot-auto renew',
    minute  => '10',
    hour    => [ '4', '16' ],
}

# Dynamic DNS (no longer in use)
service { 'ddclient':
    ensure  => 'stopped',
    enable  => 'false',
}
# NoIP dynamic update client
file { '/usr/sbin/noip2':
    mode => '0555',
    owner => 'root',
    group => 'root',
    source => 'puppet:///modules/noip/noip2-x86_64',
} ->
# To generate noip-master.cfg, run `noip2 -C -c /etc/noip-master.cfg`
file { '/etc/noip.cfg':
    mode => '0444',
    owner => 'root',
    group => 'root',
    source => '/etc/noip-master.cfg',
} ~>
service { 'noip2':
    ensure => 'running',
    binary => '/usr/sbin/noip2',
    hasrestart => 'false',
    hasstatus => 'false',
    provider => 'base',
    start => '/usr/sbin/noip2 -c /etc/noip.cfg',
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
    ssl_cert       => '/etc/letsencrypt/live/balthasar.viewdns.net/cert.pem',
    ssl_key        => '/etc/letsencrypt/live/balthasar.viewdns.net/privkey.pem',
    ssl_chain      => '/etc/letsencrypt/live/balthasar.viewdns.net/chain.pem',
    ssl_protocol   => 'all -SSLv2 -SSLv3',
    ssl_cipher     => 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA',
    ssl_honorcipherorder => 'on',
    ssl_options    => [ '+StrictRequire' ],
    serveraliases  => [ 'balthasar.viewdns.net', 'balthasar.logastro.com' ],
}
