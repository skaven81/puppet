# Class: ssmtp::config
#
# This module contain the configuration for sSMTP
#
# Parameters:   This module has no parameters
#
# Actions:      This module has no actions
#
# Requires:     This module has no requirements
#
# Sample Usage: include ssmtp::config
#
class ssmtp::config {

  # sSMTP configuration
  file {
    $ssmtp::params::configSsmtpConf:
      ensure  => present,
      mode    => '0644',
      owner   => root,
      group   => root,
      path    => $ssmtp::params::configSsmtpConf,
      content => template($ssmtp::params::configSsmtpConfTemplate);

    $ssmtp::params::configRevaliasesConf:
      ensure  => present,
      mode    => '0644',
      owner   => root,
      group   => root,
      path    => $ssmtp::params::configRevaliasesConf,
      content => template($ssmtp::params::configRevaliasesConfTemplate);
  }
}
