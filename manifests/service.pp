# @summary Manages the Plex service via the selected service manager.
# @api private
class plexmediaserver::service {
  assert_private()

  if $plexmediaserver::service_manager_real == 'supervisord' {
    exec { 'plex-supervisor-update':
      command     => ['/usr/bin/supervisorctl', 'update'],
      refreshonly => true,
      path        => ['/usr/bin', '/bin', '/usr/local/bin'],
    }
  } else {
    service { 'plexmediaserver':
      ensure => 'running',
      enable => true,
    }
  }
}
