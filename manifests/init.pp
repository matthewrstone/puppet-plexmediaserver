# class plexmediaserver
# Installs Plex Media Server with sane defaults.
# Package repository information taken from
# https://support.plex.tv/articles/235974187-enable-repository-updating-for-supported-linux-server-distributions/
#
# @param repo_uri
#   Base URI for the Plex repository.
#   Default: 'https://repo.plex.tv'
#
# @param gpg_key_uri
#   URI for the Plex GPG key.
#   Default: 'https://downloads.plex.tv/plex-keys/PlexSign.v2.key'
#
# @param install_version
#   Package version to install.
#   Default: 'latest'
#
# @param use_letsencrypt
#   Whether to configure Plex Media Server to use Let's Encrypt certificates for secure access.
#   Default: false
#
# @param ensure
#   Whether the package should be present or absent.
#   Default: 'present'
#
class plexmediaserver (
  Stdlib::HTTPSUrl $repo_uri        = 'https://repo.plex.tv',
  Stdlib::HTTPSUrl $gpg_key_uri     = 'https://downloads.plex.tv/plex-keys/PlexSign.v2.key',
  String $install_version           = 'latest',
  Boolean $use_letsencrypt          = false,
  Enum['present', 'absent'] $ensure = 'present',
) {
  $family = $facts['os']['family']
  case $family {
    'RedHat': {
      yum::repo { 'Plex.tv':
        ensure        => present,
        baseurl       => "${repo_uri}/rpm/",
        gpgkey        => $gpg_key_uri,
        enabled       => 1,
        gpgcheck      => 1,
        repo_gpgcheck => 1,
      }
    }
    'Debian': {
      apt::source { 'plexmediaserver':
        ensure   => present,
        location => "${repo_uri}/deb/",
        repos    => 'public main',
        key      => {
          name   => 'PlexSign.v2',
          source => $gpg_key_uri,
        },
      }
    }
    default: {
      fail("Unsupported OS family ${family} for plexmediaserver. Supported families are RedHat and Debian.")
    }
  }
  package { 'plexmediaserver':
    ensure => $install_version,
  }

  service { 'plexmediaserver':
    ensure  => 'present',
    enable  => true,
    require => Package['plexmediaserver'],
  }

  if $use_letsencrypt {
    include plexmediaserver::secure
  }
}
