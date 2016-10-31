# This manifest is for configuring my workstation

include ::pubkeys

# Packages
package { [ 'puppet' ]:
    ensure  => 'latest',
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid/puppet/modules /raid/puppet/manifests/token.pp  | grep -v "Finished catalog run"',
    minute  => 0,
    hour    => '*',
}

# Mail relay
class { '::ssmtp':
    rootEmail => 'paul.krizak@gmail.com',
    mailHub => '192.168.1.50',
} ->
package { 'postfix':
    ensure => 'absent',
}

class { '::ntp':
    ignore_local_clock => true,
}

# Hosts file and nsswitch
class { 'nsswitch':
    hosts => ['files', 'dns'],
}

