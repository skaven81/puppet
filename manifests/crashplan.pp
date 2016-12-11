# This manifest is for configuring
# the Crashplan VM on Geofront

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
mount { '/crashplan-store':
    ensure => 'mounted',
    device => 'geofront:/raid/crashplan-store',
    fstype => 'nfs',
    options => 'rw,vers=3',
    dump    => '0',
    pass    => '0',
}
mount { '/raid5':
    ensure => 'mounted',
    device => 'geofront:/raid',
    fstype => 'nfs',
    options => 'ro,vers=3',
    dump    => '0',
    pass    => '0',
}
mount { '/geofront-root/etc':
    ensure => 'mounted',
    device => 'geofront:/etc',
    fstype => 'nfs',
    options => 'ro,vers=3',
    dump    => '0',
    pass    => '0',
}
mount { '/geofront-root/var/named':
    ensure => 'mounted',
    device => 'geofront:/var/named',
    fstype => 'nfs',
    options => 'ro,vers=3',
    dump    => '0',
    pass    => '0',
}
mount { '/geofront-root/usr/share/ipkungfu':
    ensure => 'mounted',
    device => 'geofront:/usr/share/ipkungfu',
    fstype => 'nfs',
    options => 'ro,vers=3',
    dump    => '0',
    pass    => '0',
}

class { '::ntp':
    ignore_local_clock => true,
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid5/puppet/modules /raid5/puppet/manifests/crashplan.pp  | grep -v "Finished catalog run"',
    minute  => 0,
    hour    => 12,
}

class { '::ssmtp':
    rootEmail => 'paul.krizak@gmail.com',
    mailHub => '192.168.86.50',
} ->
package { 'postfix':
    ensure => 'absent',
}
