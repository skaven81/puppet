class geofront::mail_client (
    $relayhost = '192.168.1.50',
    $root_dest = 'root',
) {
    class {'::postfix::server':
        relayhost => "[${relayhost}]",
    }

    file { '/etc/aliases':
        content => template('geofront/mail_aliases.erb')
    } ->
    exec { '/usr/bin/newaliases':
        refreshonly => true,
    }
}
