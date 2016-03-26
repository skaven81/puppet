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
    password => '$6$Fu6Hrk4t$BCSShVBvCp6XNActMOxyL/EQhqssmKgaydXbNMOG7nulTnXJRgRLpkXxo30pzuMK8AL/qDcphbWplejFrC67Y1',
}
# Add an extra authorized key for root's login
# so I can login using my phone too
ssh_authorized_key { 'galaxy_note_4@geofront':
    user    => 'root',
    key     => $::pubkeys::galaxy_note_4,
    type    => $::pubkeys::galaxy_note_4_type,
}
account {'skaven':
    ensure      => 'present',
    uid         => 1000,
    shell       => '/bin/bash',
    home_dir    => '/home/skaven',
    manage_home => false,
    create_group => false,
    groups      => [ 'users', 'skaven', 'wheel', 'kvm', 'dockerroot' ],
}
account {'lori':
    ensure      => 'present',
    uid         => 500,
    shell       => '/bin/bash',
    home_dir    => '/home/lori',
    manage_home => false,
    create_group => false,
    groups      => [ 'users', 'lori' ],
}

# Packages
package { [ 'puppet' ]:
    ensure  => 'latest',
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid/puppet/modules /raid/puppet/manifests/geofront.pp  | grep -v "Finished catalog run"',
    minute  => 0,
    hour    => 12,
}

file { '/etc/cron.weekly/astro_photo_cleanup':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => '#!/bin/bash
IFS=$\'\n\t\'
for ext in avi nef tif; do
    find /raid/astro_photos -mtime +7 -iname *.$ext | \
    while read line; do 
        zip -9 -m $line.zip $line
    done
done
',
}

# ddclient configuration
file { '/etc/ddclient/ddclient.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => template("ddclient/ddclient.conf"),
}
file { '/usr/sbin/ddclient':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0555',
    content => template("ddclient/ddclient"),
}

# Mail relay configuration
class { '::postfix::server':
    extra_main_parameters => {
        smtp_use_tls => 'yes',
        smtp_sasl_auth_enable => 'yes',
        smtp_sasl_password_maps => 'hash:/etc/postfix/password',
        smtp_sasl_security_options => 'noanonymous',
        smtp_tls_CAfile => '/etc/postfix/cacert.pem',
        mynetworks_style => 'subnet',
        mynetworks => '192.168.1.0/24, 127.0.0.1/8',
        relayhost => '[smtp.gmail.com]:587',
        },
    inet_interfaces => 'localhost',
} ->
file { '/etc/postfix/password':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => "[smtp.gmail.com]:587 paul.krizak@gmail.com:skfzjiuxelpegpxw\n",
    notify  => Exec['postmap'],
} ->
file { '/etc/postfix/cacert.pem':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '444',
    # Equifax Secure CA
    content => "-----BEGIN CERTIFICATE-----
MIIDIDCCAomgAwIBAgIENd70zzANBgkqhkiG9w0BAQUFADBOMQswCQYDVQQGEwJV
UzEQMA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2Vy
dGlmaWNhdGUgQXV0aG9yaXR5MB4XDTk4MDgyMjE2NDE1MVoXDTE4MDgyMjE2NDE1
MVowTjELMAkGA1UEBhMCVVMxEDAOBgNVBAoTB0VxdWlmYXgxLTArBgNVBAsTJEVx
dWlmYXggU2VjdXJlIENlcnRpZmljYXRlIEF1dGhvcml0eTCBnzANBgkqhkiG9w0B
AQEFAAOBjQAwgYkCgYEAwV2xWGcIYu6gmi0fCG2RFGiYCh7+2gRvE4RiIcPRfM6f
BeC4AfBONOziipUEZKzxa1NfBbPLZ4C/QgKO/t0BCezhABRP/PvwDN1Dulsr4R+A
cJkVV5MW8Q+XarfCaCMczE1ZMKxRHjuvK9buY0V7xdlfUNLjUA86iOe/FP3gx7kC
AwEAAaOCAQkwggEFMHAGA1UdHwRpMGcwZaBjoGGkXzBdMQswCQYDVQQGEwJVUzEQ
MA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2VydGlm
aWNhdGUgQXV0aG9yaXR5MQ0wCwYDVQQDEwRDUkwxMBoGA1UdEAQTMBGBDzIwMTgw
ODIyMTY0MTUxWjALBgNVHQ8EBAMCAQYwHwYDVR0jBBgwFoAUSOZo+SvSspXXR9gj
IBBPM5iQn9QwHQYDVR0OBBYEFEjmaPkr0rKV10fYIyAQTzOYkJ/UMAwGA1UdEwQF
MAMBAf8wGgYJKoZIhvZ9B0EABA0wCxsFVjMuMGMDAgbAMA0GCSqGSIb3DQEBBQUA
A4GBAFjOKer89961zgK5F7WF0bnj4JXMJTENAKaSbn+2kmOeUJXRmm/kEd5jhW6Y
7qj/WsjTVbJmcVfewCHrPSqnI0kBBIZCe/zuf6IWUrVnZ9NA2zsmWLIodz2uFHdh
1voqZiegDfqnc1zqcPGUIWVEX/r87yloqaKHee9570+sB3c4
-----END CERTIFICATE-----\n",
}
exec { 'postmap':
    refreshonly => true,
    command     => "/usr/sbin/postmap /etc/postfix/password",
    creates     => "/etc/postfix/password.db",
}
 
class { '::ntp':
    ignore_local_clock => true,
}


# RAID configuration
file { '/etc/mdadm.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '444',
    content => "MAILADDR paul.krizak@gmail.com
#AUTO +imsm +1.x -all
ARRAY /dev/md127 devices=/dev/sd[bcd]
"
}

mount { '/raid':
    device => "/dev/mapper/vg_raid-lv_raid",
    ensure => "mounted",
    atboot => true,
    fstype => 'ext3',
    options => 'noatime',
    pass    => 2,
    dump    => 1,
} ->
file { '/raid1':
    ensure => 'link',
    target => '/raid',
} ->
file { '/raid5':
    ensure => 'link',
    target => '/raid',
} ->
file { '/raid6':
    ensure => 'link',
    target => '/raid',
} ->
file { '/home':
    ensure => 'link',
    target => '/raid6/user',
}

# Raid-check utility configuration
file { '/etc/sysconfig/raid-check':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '444',
    content => "#!/bin/bash
#
# Configuration file for /usr/sbin/raid-check
#
# options:
#	ENABLED - must be yes in order for the raid check to proceed
#	CHECK - can be either check or repair depending on the type of
#		operation the user desires.  A check operation will scan
#		the drives looking for bad sectors and automatically
#		repairing only bad sectors.  If it finds good sectors that
#		contain bad data (meaning that the data in a sector does
#		not agree with what the data from another disk indicates
#		the data should be, for example the parity block + the other
#		data blocks would cause us to think that this data block
#		is incorrect), then it does nothing but increments the
#		counter in the file /sys/block/$dev/md/mismatch_count.
#		This allows the sysadmin to inspect the data in the sector
#		and the data that would be produced by rebuilding the
#		sector from redundant information and pick the correct
#		data to keep.  The repair option does the same thing, but
#		when it encounters a mismatch in the data, it automatically
#		updates the data to be consistent.  However, since we really
#		don't know whether it's the parity or the data block that's
#		correct (or which data block in the case of raid1), it's
#		luck of the draw whether or not the user gets the right
#		data instead of the bad data.  This option is the default
#		option for devices not listed in either CHECK_DEVS or
#		REPAIR_DEVS.
#	CHECK_DEVS - a space delimited list of devs that the user specifically
#		wants to run a check operation on.
#	REPAIR_DEVS - a space delimited list of devs that the user
#		specifically wants to run a repair on.
#	SKIP_DEVS - a space delimited list of devs that should be skipped
#       NICE - Change the raid check CPU and IO priority in order to make
#		the system more responsive during lengthy checks.  Valid
#		values are high, normal, low, idle.
#	MAXCONCURENT - Limit the number of devices to be checked at a time.
#		By default all devices will be checked at the same time.
#
# Note: the raid-check script is run by the /etc/cron.d/raid-check cron job.
# Users may modify the frequency and timing at which raid-check is run by
# editing that cron job and their changes will be preserved across updates
# to the mdadm package.
#
# Note2: you can not use symbolic names for the raid devices, such as you
# /dev/md/root.  The names used in this file must match the names seen in
# /proc/mdstat and in /sys/block.

ENABLED=yes
CHECK=repair
NICE=low
# To check devs /dev/md0 and /dev/md3, use \"md0 md3\"
CHECK_DEVS=\"\"
REPAIR_DEVS=\"md127\"
SKIP_DEVS=\"\"
MAXCONCURRENT=\n
"}
file { "/etc/cron.d/raid-check":
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '400',
    content => "# Run system wide raid-check once a week on Sunday at 1am by default
0 1 * * Sun root /usr/sbin/raid-check
"
}
file { "/etc/cron.d/raid-email":
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '400',
    content => "# E-mail sysadmin if RAID has gone off in the weeds
0 1 * * * root /bin/bash -c 'grep -q \"blocks super.*_\" /proc/mdstat && mail -s \"RAID on geofront is wonky\" paul.krizak@gmail.com < /proc/mdstat'
"
}

# SSH configuration
sshd_config { "ListenAddress":
    ensure => present,
    value  => "192.168.1.50",
    notify => Service['sshd'],
}
sshd_config { "PermitRootLogin":
    ensure => present,
    value  => "yes",
    notify => Service['sshd'],
}
sshd_config { "AllowUsers":
    ensure => present,
    value  => [ "skaven", "root" ],
    notify => Service['sshd'],
}
sshd_config { "PasswordAuthentication":
    ensure => present,
    value  => "no", notify => Service['sshd'],
}
sshd_config { "AuthorizedKeysFile":
    ensure => present,
    value  => ".ssh/authorized_keys",
    notify => Service['sshd'],
}
service { "sshd":
    ensure => running,
    hasrestart => true,
}

# Hosts file and nsswitch
include ::geofront::hosts
class { 'nsswitch':
    hosts => ['files', 'dns'],
    passwd => 'files',
    shadow => 'files',
    group  => 'files',
}

# Docker configuration
package { 'docker-io':
    ensure => 'installed',
} ->
service { 'docker':
    ensure => 'running',
    enable => 'true',
} ->
file { '/var/run/docker.sock':
    owner => 'root',
    group => 'dockerroot',
}
