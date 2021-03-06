# Class: yum::config::puppetlabs
#
# This module contain the configuration for yum Puppetlabs repository
#
# Parameters:   This module has no parameters
#
# Actions:      This module has no actions
#
# Requires:     This module has no requirements
#
# Sample Usage:
#
class yum::config::puppetlabs {
  file { $yum::params::elPuppetlabsFile:
    ensure  => present,
    mode    => '0644',
    owner   => root,
    group   => root,
    path    => $yum::params::elPuppetlabsFile,
    notify  => Exec['yum-cache', 'yum-rpm-key-import'],
    content => template($yum::params::elPuppetlabsTemplate);
  }
}
