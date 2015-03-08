# This manifest is for configuring
# the main Geofront host

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

# Packages
package { [ 'puppet' ]:
    ensure  => 'latest',
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid/puppet/modules /raid/puppet/manifests/www.pp  | grep -v "Finished catalog run"',
    minute  => 0,
    hour    => 12,
}

# Mail relay configuration
class { '::postfix::server':
    extra_main_parameters => {
        smtp_use_tls => 'yes',
        smtp_sasl_auth_enable => 'yes',
        smtp_sasl_password_maps => 'hash:/etc/postfix/password',
        smtp_sasl_security_options => 'noanonymous',
        smtp_tls_CAfile => '/etc/postfix/cacert.pem',
        },
    relayhost => '[smtp.gmail.com]:587',
} ->
file { '/etc/postfix/password':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => "[smtp.gmail.com]:587 paul.krizak@gmail.com:skfzjiuxelpegpxw\n",
    notify  => Exec['postmap'],
}
exec { 'postmap':
    refreshonly => true,
    command     => "/usr/sbin/postmap /etc/postfix/password",
    creates     => "/etc/postfix/password.db",
}
 
