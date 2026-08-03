# @summary Install and manage Plex Media Server on VMs (systemd) or LXC (supervisord).
#
# Package repository information taken from
# https://support.plex.tv/articles/235974187-enable-repository-updating-for-supported-linux-server-distributions/
#
# @param repo_uri
#   Base URI for the Plex repository.
# @param gpg_key_uri
#   URI for the Plex GPG key.
# @param install_version
#   Package version to install ('latest' or a pinned version).
# @param use_letsencrypt
#   Whether to configure Let's Encrypt certificates for secure access.
# @param ensure
#   Whether the package should be present or absent.
# @param service_manager
#   Force the service manager. When undef (default), it is derived from the
#   `virtual` fact: 'lxc' => supervisord, everything else => systemd.
# @param plex_user
#   User the Plex process runs as (supervisord path).
# @param plex_group
#   Group the Plex process runs as (supervisord path).
# @param plex_binary
#   Absolute path to the Plex Media Server binary (supervisord path).
# @param plex_support_dir
#   Plex application support directory (supervisord path).
# @param supervisor_package
#   Name of the supervisor package (OS-family default from module data).
# @param supervisor_conf_dir
#   Directory supervisord reads program configs from (OS-family default).
# @param supervisor_conf_ext
#   File extension for supervisor program configs (OS-family default).
class plexmediaserver (
  Stdlib::HTTPSUrl $repo_uri                                = 'https://repo.plex.tv',
  Stdlib::HTTPSUrl $gpg_key_uri                             = 'https://downloads.plex.tv/plex-keys/PlexSign.v2.key',
  String $install_version                                  = 'latest',
  Boolean $use_letsencrypt                                 = false,
  Enum['present', 'absent'] $ensure                        = 'present',
  Optional[Enum['systemd', 'supervisord']] $service_manager = undef,
  String $plex_user                                        = 'plex',
  String $plex_group                                       = 'plex',
  Stdlib::Absolutepath $plex_binary                        = '/usr/lib/plexmediaserver/Plex Media Server',
  Stdlib::Absolutepath $plex_support_dir                   = '/var/lib/plexmediaserver/Library/Application Support',
  String $supervisor_package                               = 'supervisor',
  Stdlib::Absolutepath $supervisor_conf_dir                = '/etc/supervisor/conf.d',
  String $supervisor_conf_ext                              = '.conf',
) {
  if $service_manager =~ Undef {
    $service_manager_real = $facts['virtual'] ? {
      'lxc'   => 'supervisord',
      default => 'systemd',
    }
  } else {
    $service_manager_real = $service_manager
  }

  contain plexmediaserver::install
  contain plexmediaserver::config
  contain plexmediaserver::service

  Class['plexmediaserver::install']
  -> Class['plexmediaserver::config']
  ~> Class['plexmediaserver::service']

  if $use_letsencrypt {
    include plexmediaserver::secure
  }
}
