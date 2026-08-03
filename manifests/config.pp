# @summary Writes service-manager configuration for Plex.
# @api private
class plexmediaserver::config {
  assert_private()

  # Supervisord program config is added in Task 3.
  # On systemd this class intentionally manages nothing (the vendor unit owns config).
}
