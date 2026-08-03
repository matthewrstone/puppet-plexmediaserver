# @summary Manages the Plex service via the selected service manager.
# @api private
class plexmediaserver::service {
  assert_private()

  if $plexmediaserver::service_manager_real == 'supervisord' {
    # Supervisord branch is added in Task 3.
  } else {
    service { 'plexmediaserver':
      ensure => 'running',
      enable => true,
    }
  }
}
