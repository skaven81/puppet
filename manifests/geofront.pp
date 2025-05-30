# vim: ts=4 sts=4 sw=4 expandtab
# This manifest is for configuring
# the main Geofront host

include ::pubkeys

# Newer Puppet has a warning if you don't explicitly
# set a default for allow_virtual
Package {
    allow_virtual => true
}

class { selinux:
    mode => 'disabled',
}

account {'root':
    ensure  => 'present',
    uid     => 0,
    shell   => '/bin/bash',
    home_dir => '/root',
    manage_home => true,
    create_group => true,
    groups  => [ 'bin', 'daemon', 'sys', 'adm', 'disk', 'wheel' ],
    ssh_keys => {
      'access' => {
        key => $::pubkeys::token,
        type => $::pubkeys::token_type,
      }
    },
    #purge_ssh_keys => true,
    password => '$6$Fu6Hrk4t$BCSShVBvCp6XNActMOxyL/EQhqssmKgaydXbNMOG7nulTnXJRgRLpkXxo30pzuMK8AL/qDcphbWplejFrC67Y1',
}
# Add an extra authorized key for root's login
# so I can login using my phone too
ssh_authorized_key { 'pixel2@geofront':
    user    => 'root',
    key     => $::pubkeys::pixel2,
    type    => $::pubkeys::pixel2_type,
}
account {'skaven':
    ensure      => 'present',
    uid         => 1000,
    shell       => '/bin/bash',
    home_dir    => '/user/skaven',
    manage_home => false,
    create_group => true,
    password    => '$6$hcePahp.$GYkEUl6b9RUTwbBhKHXRLKqlbHgzSwo1NDB.Tx1P5J2Kj11Qq7JPZZJ9F.WqPB6wIRCY1BEcYQcr.nr4hGvhv/',
    groups      => [ 'users', 'skaven', 'wheel', 'docker' ],
}
account {'lori':
    ensure      => 'present',
    uid         => 500,
    shell       => '/bin/bash',
    home_dir    => '/user/lori',
    manage_home => false,
    create_group => true,
    groups      => [ 'users', 'lori' ],
}

# Packages
package { [ 'openvox-agent' ]:
    ensure  => 'latest',
} ->
file { '/usr/bin/puppet':
    ensure => 'link',
    target => '/opt/puppetlabs/bin/puppet',
}

cron { 'puppet':
    ensure  => 'present',
    user    => 'root',
    command => '/usr/bin/puppet apply --modulepath=/raid/puppet/modules /raid/puppet/manifests/geofront.pp 2>&1 | grep -v "Finished catalog run" | grep -v "Compiled catalog" | grep -v "hiera.yaml"',
    minute  => 0,
    hour    => 12,
}

# Disable avahi since it can conflict with Samba
service { 'avahi-daemon.socket':
    ensure => 'stopped',
    enable => 'false',
} ->
service { 'avahi-daemon':
    ensure => 'stopped',
    enable => 'false',
}

file { '/etc/cron.weekly/astro_photo_cleanup':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => '#!/bin/bash
IFS=$\'\n\t\'
find /raid/astro_photos -name DELETE* -delete
for ext in avi nef tif; do
    find /raid/astro_photos -mtime +7 -iname *.$ext | \
    while read line; do 
        zip -9 -m $line.zip $line
    done
done
',
}

# Shutdown and restart containers since they tend to grow due
# to logs and stuff that haven't been offloaded to host paths
file { '/etc/cron.weekly/homeservices_restart':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => '#!/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
cd ~skaven/git/HomeServices
docker-compose down --volumes
docker-compose up -d
',
}

# ### cups configuration ###
# This just sets up the server.  You still have to add the printer:
# 1. Download the ML1660 Linux drivers (should be in /raid/linux-drivers)
# 2. Install the Linux drivers (creates some dirs in /opt and drops the
#       raster bits into /usr/lib/cups/filter/)
# 3. Go to https://geofront:631 (login as skaven)
# 4. Add printer, use local detected USB
# 5. When prompted, use PPD from the driver tarball (noarch/share/ppd...)
#
# Access the printer using the URI `http://geofront:631/printers/ml1660`
package { 'cups':
    ensure  => 'installed',
} ->
package { 'sane-backends':
    ensure => 'installed',
} ->
file { '/etc/cups/cupsd.conf':
    ensure  => 'present',
    owner   => 'root',
    group   => 'lp',
    mode    => '0640',
    content => template("cups/cupsd.conf"),
    notify  => Service['cups'],
} ->
service { 'cups':
    ensure  => 'running',
    enable  => true,
}

# These packages are needed so postfix can do SASL auth to Gmail
package { ['cyrus-sasl', 'cyrus-sasl-lib', 'cyrus-sasl-plain']:
    ensure => 'installed',
}
# Mail relay configuration
# NOTE: geofront's FQDN needs to be listed first in /etc/hosts next to
# its IP address:
#   192.168.86.50    geofront.logastro.com geofront geofront.spectrum.local
# If the short name is listed first, `hostname -f` doesn't return a full
# hostname, and postfix gets very confused about which domains should relay mail.
class { '::postfix::server':
    extra_main_parameters => {
        smtp_use_tls => 'yes',
        smtp_sasl_auth_enable => 'yes',
        inet_protocols => 'ipv4',
        # the /etc/postfix/password file has to contain
        # [smtp.gmail.com]:587  <gmail account>:<app password>
        # then run /usr/sbin/postmap /etc/postfix/password
        # See https://support.google.com/accounts/answer/185833?hl=en
        # create app passwords at https://myaccount.google.com/apppasswords
        smtp_sasl_password_maps => 'hash:/etc/postfix/password',
        smtp_sasl_security_options => 'noanonymous',
        smtp_tls_CAfile => '/etc/postfix/cacert.pem',
        mynetworks_style => 'subnet',
        mynetworks => '192.168.86.0/24, 127.0.0.1/8',
        relayhost => '[smtp.gmail.com]:587',
        },
    inet_interfaces => 'localhost',
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

package { 's-nail':
    ensure => 'installed'
}
 
class { 'chrony':
    #ignore_local_clock => true,
}


# RAID configuration
file { '/etc/mdadm.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '444',
    content => "MAILADDR paul.krizak@gmail.com
#AUTO +imsm +1.x -all
ARRAY /dev/md127 devices=/dev/sd[bcde]
"
}

mount { '/raid':
    device => "/dev/mapper/vg_geofront-lv_raid",
    ensure => "mounted",
    atboot => true,
    fstype => 'xfs',
    options => 'noatime,logdev=/dev/mapper/vg_geofront-lv_raid_journal,x-systemd.requires=/dev/mapper/vg_geofront-lv_raid_journal,nofail',
    pass    => 0,
    dump    => 0,
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
}
file { '/user':
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
#		counter in the file /sys/block/\$dev/md/mismatch_count.
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
file { "/etc/cron.d/sys-rw":
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '400',
    content => "# Remounting /sys read-write is due to this bug: https://github.com/docker/docker/issues/7101
# with docker.  When /sys goes read-only, mdadm goes haywire
*/10 * * * * root mount -o remount,rw /sys
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
    value  => "192.168.86.50",
    notify => Service['sshd'],
}
# Root should only be able to login with a pubkey
# via SSH.  Note that root can still get in via
# the physical console with a password.
sshd_config { "PermitRootLogin":
    ensure => present,
    value  => "without-password",
    notify => Service['sshd'],
}
# This makes it so we only have to secure two accounts
sshd_config { "AllowUsers":
    ensure => present,
    value  => [ "skaven", "root" ],
    notify => Service['sshd'],
}
# So that the PAM stack gets invoked for passwords, if
# a pubkey is not present.  Google authenticator is required
# as well if password auth is used.
sshd_config { "PasswordAuthentication":
    ensure => present,
    value  => "yes",
    notify => Service['sshd'],
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
class { 'nsswitch':
    hosts => ['files', 'dns'],
    passwd => 'files',
    shadow => 'files',
    group  => 'files',
}

# Make sure we have plenty of inotify handles
sysctl { 'fs.inotify.max_user_watches': value => '1048576' }
sysctl { 'net.ipv4.ip_forward': value => '1' }

# Docker configuration
file { '/etc/yum.repos.d/docker-ce.repo':
    ensure => 'present',
    source => 'https://download.docker.com/linux/rhel/docker-ce.repo',
} ->
package { 'docker-ce':
    ensure => 'latest',
} ->
service { 'docker':
    ensure => 'running',
}
package { 'docker-compose-plugin':
    ensure => 'latest',
}

# Set up NFS
file { '/etc/sysconfig/nfs':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    notify  => Service['nfs-server'],
    content => '
#
#
# To set lockd kernel module parameters please see
#  /etc/modprobe.d/lockd.conf
#

# Optional arguments passed to rpc.nfsd. See rpc.nfsd(8)
# geofront: enable v4.2
RPCNFSDARGS="-V 4.2"
# Number of nfs server processes to be started.
# The default is 8. 
#RPCNFSDCOUNT=16
#
# Set V4 grace period in seconds
#NFSD_V4_GRACE=90
#
# Set V4 lease period in seconds
#NFSD_V4_LEASE=90
#
# Optional arguments passed to rpc.mountd. See rpc.mountd(8)
RPCMOUNTDOPTS=""
# Port rpc.mountd should listen on.
#MOUNTD_PORT=892
#
# Optional arguments passed to rpc.statd. See rpc.statd(8)
STATDARG=""
# Port rpc.statd should listen on.
#STATD_PORT=662
# Outgoing port statd should used. The default is port
# is random
#STATD_OUTGOING_PORT=2020
# Specify callout program
#STATD_HA_CALLOUT="/usr/local/bin/foo"
#
#
# Optional arguments passed to sm-notify. See sm-notify(8)
SMNOTIFYARGS=""
#
# Optional arguments passed to rpc.idmapd. See rpc.idmapd(8)
RPCIDMAPDARGS=""
#
# Optional arguments passed to rpc.gssd. See rpc.gssd(8)
# Note: The rpc-gssd service will not start unless the 
#       file /etc/krb5.keytab exists. If an alternate
#       keytab is needed, that separate keytab file
#       location may be defined in the rpc-gssd.services
#       systemd unit file under the ConditionPathExists
#       parameter
RPCGSSDARGS=""
#
# Enable usage of gssproxy. See gssproxy-mech(8).
GSS_USE_PROXY="yes"
#
# Optional arguments passed to blkmapd. See blkmapd(8)
BLKMAPDARGS=""
'
}
package { 'nfs-utils':
    ensure  => 'present',
} ->
file { '/etc/exports':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => '/raid 192.168.86.0/24(rw,async,root_squash,no_subtree_check)
',
    notify  => Exec['exportfs'],
} ->
service { 'nfs-server':
    ensure  => 'running',
    enable => 'true',
}
exec { 'exportfs':
    refreshonly => true,
    command     => "/usr/sbin/exportfs -a",
}

# Disable the firewall
service { 'firewalld':
    ensure => 'stopped',
}

# Disable selinux
file { '/etc/sysconfig/selinux':
    ensure => 'link',
    target => '/etc/selinux/config',
}
file { '/etc/selinux/config':
    ensure => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => '# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of three two values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected. 
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted 
',
}
 
package { 'epel-release':
    ensure => 'present',
    provider => 'rpm',
    source => 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm',
}

# Configure Google Authenticator TOTP
# https://www.digitalocean.com/community/tutorials/how-to-set-up-multi-factor-authentication-for-ssh-on-centos-7
package { 'google-authenticator':
    ensure => 'present',
}
file_line { 'ssh-google-pam':
    path => '/etc/pam.d/sshd',
    line => 'auth required pam_google_authenticator.so',
}
sshd_config { "ChallengeResponseAuthentication":
    ensure => present,
    value  => "yes",
    notify => Service['sshd'],
}
# keyboard-interactive invokes the PAM stack
# for AuthN, which due to the update above
# to include the pam_google_authenticator module,
# results in a password + token check.  For
# pubkey auth, the PAM stack is bypassed, so
# no token challenge is used.  If we want pubkey+token
# OR password+token, that can't be done, because both
# password and token are handled by the same keyboard-interactive
# directive via PAM.  So the configuration below allows
# pubkey (without token; no PAM) or password+token, for users
# with UIDs >= 1000 (as defined in /etc/pam.d/password-auth).
sshd_config { "AuthenticationMethods":
    ensure => present,
    value => "publickey keyboard-interactive",
    notify => Service['sshd'],
}

