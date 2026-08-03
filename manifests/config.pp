# @summary Writes service-manager configuration for Plex.
# @api private
class plexmediaserver::config {
  assert_private()

  if $plexmediaserver::service_manager_real == 'supervisord' {
    $program_config = "${plexmediaserver::supervisor_conf_dir}/plexmediaserver${plexmediaserver::supervisor_conf_ext}"

    file { $program_config:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('plexmediaserver/supervisord-program.epp', {
          'plex_binary'      => $plexmediaserver::plex_binary,
          'plex_user'        => $plexmediaserver::plex_user,
          'plex_support_dir' => $plexmediaserver::plex_support_dir,
      }),
    }
  }
  # On systemd this class intentionally manages nothing (the vendor unit owns config).
}
