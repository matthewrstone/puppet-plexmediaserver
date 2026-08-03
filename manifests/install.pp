# @summary Configures the Plex repository and installs the package.
# @api private
class plexmediaserver::install {
  assert_private()

  $package_ensure = $plexmediaserver::ensure ? {
    'absent' => 'absent',
    default  => $plexmediaserver::install_version,
  }

  $family = $facts['os']['family']
  case $family {
    'RedHat': {
      yumrepo { 'Plex.tv':
        ensure        => present,
        descr         => 'Plex.tv',
        baseurl       => "${plexmediaserver::repo_uri}/rpm/",
        gpgkey        => $plexmediaserver::gpg_key_uri,
        enabled       => 1,
        gpgcheck      => 1,
        repo_gpgcheck => 1,
      }

      Yumrepo['Plex.tv'] -> Package['plexmediaserver']
    }
    'Debian': {
      exec { 'import-plex-gpg-key':
        command => "/usr/bin/curl -fsSL ${plexmediaserver::gpg_key_uri} | /usr/bin/gpg --yes --dearmor -o /usr/share/keyrings/plexmediaserver.v2.gpg",
        creates => '/usr/share/keyrings/plexmediaserver.v2.gpg',
      }

      apt::source { 'plex':
        location => "${plexmediaserver::repo_uri}/deb/",
        repos    => 'main',
        release  => 'public',
        keyring  => '/usr/share/keyrings/plexmediaserver.v2.gpg',
        require  => Exec['import-plex-gpg-key'],
        notify   => Class['apt::update'],
      }

      Class['apt::update'] -> Package['plexmediaserver']
    }
    default: {
      fail("Unsupported OS family ${family} for plexmediaserver. Supported families are RedHat and Debian.")
    }
  }

  package { 'plexmediaserver':
    ensure => $package_ensure,
  }

  if $plexmediaserver::service_manager_real == 'supervisord' {
    package { $plexmediaserver::supervisor_package:
      ensure => present,
    }
  }
}
