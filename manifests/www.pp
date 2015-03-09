# This manifest is for configuring
# the WWW VM on Geofront

include ::pubkeys

account {'root':
    ensure  => 'present',
    uid     => 0,
    shell   => '/bin/bash',
    home_dir => '/root',
    manage_home => true,
    create_group => true,
    groups  => [ 'bin', 'daemon', 'sys', 'adm', 'disk', 'wheel' ],
    ssh_key => $::pubkeys::token,
    ssh_key_type => $::pubkeys::token_type,
    purge_ssh_keys => true,
}
account {'skaven':
    ensure  => 'present',
    uid     => 1000,
    gid     => 1000,
    shell   => '/sbin/nologin',
    manage_home => false,
}

# Packages
package { [ 'puppet' ]:
    ensure  => 'latest',
}

# NFS mounts
mount { '/raid6':
    ensure => 'mounted',
    device => 'geofront:/raid6',
    fstype => 'nfs',
    options => 'ro',
    dump    => '0',
    pass    => '0',
}

host { 'www':
    ensure => 'present',
    ip     => $ipaddress,
    host_aliases => 'www.ska',
}
host { 'geofront':
    ensure => 'present',
    ip     => '192.168.1.50',
    host_aliases => 'geofront.ska',
}

class { '::ntp':
    servers => [ '192.168.1.1' ],
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid6/puppet/modules /raid6/puppet/manifests/www.pp  | grep -v "Finished catalog run"',
    minute  => 0,
    hour    => 12,
}

class { '::ssmtp':
    rootEmail => 'paul.krizak@gmail.com',
    mailHub => '192.168.1.50',
} ->
package { 'postfix':
    ensure => 'absent',
}

# Fonts, for Subsonic
package { [ 'bitmap-fixed-fonts', 'bitmap-lucida-typewriter-fonts',
            'dejavu-lgc-sans-mono-fonts', 'dejavu-sans-fonts', 'dejavu-sans-mono-fonts', 'dejavu-serif-fonts', ]:
    ensure => 'installed',
    notify => Service['subsonic'],
}

# Subsonic
package { 'subsonic':
    ensure => 'installed'
} ->
service { 'subsonic':
    ensure => 'running',
    hasrestart => true,
} ->
file { '/var/subsonic/music_links':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
} ->
file {
    '/var/subsonic/music_links/Alan':
        ensure => 'link',
        target => '/raid6/Alans Music';

    '/var/subsonic/music_links/MP3s':
        ensure => 'link',
        target => '/raid6/MP3s';

    '/var/subsonic/music_links/lori':
        ensure => 'link',
        target => '/raid6/user/lori/My Documents/My Music';
}

# Apache
class { 'apache':
    default_confd_files => false,
    default_mods        => false,
    default_vhost       => true,
    default_ssl_vhost   => true,
    package_ensure      => 'present',
    service_ensure      => 'running',
    server_signature    => 'On',
    trace_enable        => 'Off',
    docroot             => '/raid6/www',
    manage_group        => true,
    manage_user         => true,
    purge_configs       => true,
    sendfile            => 'Off',
}
Apache::Vhost <| title == 'default' |> {
    docroot_owner => 'apache',
    docroot_group => 'apache',
    manage_docroot => false,
    custom_fragment => '
<Location /server-status>
  SetHandler server-status
  Order allow,deny
  Allow from all
</Location>',
}
Apache::Vhost <| title == 'default-ssl' |> {
    docroot_owner => 'apache',
    docroot_group => 'apache',
    manage_docroot => false,
    custom_fragment => '
<Location /server-status>
  SetHandler server-status
  Order allow,deny
  Allow from all
</Location>',
}
class {'apache::mod::autoindex':}
class {'apache::mod::status':}
class {'apache::mod::userdir':}
class {'apache::mod::php':}
