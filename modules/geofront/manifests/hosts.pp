class geofront::hosts {
    host { 'wap':
        ensure => present,
        host_aliases => 'wap.attlocal.net',
        ip => '192.168.1.251',
    }
    host { 'geofront':
        ensure => present,
        host_aliases => 'geofront.attlocal.net',
        ip => '192.168.1.50',
    }
}
