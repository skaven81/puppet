class geofront::hosts {
    host { 'geofront':
        ensure => present,
        host_aliases => 'geofront.attlocal.net',
        ip => '192.168.1.50',
    }
    host { 'netsvc':
        ensure => present,
        host_aliases => 'netsvc.attlocal.net',
        ip => '192.168.1.1',
    }
    host { 'www':
        ensure => present,
        host_aliases => 'www.attlocal.net',
        ip => '192.168.1.51',
    }
    host { 'crashplan':
        ensure => present,
        host_aliases => 'crashplan.attlocal.net',
        ip => '192.168.1.52',
    }
    host { 'token':
        ensure => present,
        host_aliases => 'token.attlocal.net',
        ip => '192.168.1.99',
    }
}
