# @summary Wires the Let's Encrypt certificate into Plex (PKCS#12 + Preferences.xml).
# @api private
class plexmediaserver::ssl {
  assert_private()

  $cert_dir      = $plexmediaserver::secure::cert_dir
  $domain_name   = $plexmediaserver::secure::domain_name
  $le_live       = "${plexmediaserver::secure::letsencrypt_conf_dir}/live/${domain_name}"
  $p12_path      = "${cert_dir}/plexmediaserver.p12"
  $password_file = "${cert_dir}/.p12_password"
  $prefs_file    = "${plexmediaserver::plex_support_dir}/Plex Media Server/Preferences.xml"
  $deploy_script = '/usr/local/bin/plexmediaserver-deploy-cert.sh'

  $restart_command = $plexmediaserver::service_manager_real ? {
    'supervisord' => '/usr/bin/supervisorctl restart plexmediaserver',
    default       => '/bin/systemctl restart plexmediaserver',
  }

  file { $cert_dir:
    ensure => directory,
    owner  => $plexmediaserver::plex_user,
    group  => $plexmediaserver::plex_user,
    mode   => '0750',
  }

  file { $password_file:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0600',
    show_diff => false,
    content   => $plexmediaserver::ssl_pkcs12_password,
    require   => File[$cert_dir],
  }

  file { $deploy_script:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('plexmediaserver/deploy-cert.sh.epp', {
        'fullchain'       => "${le_live}/fullchain.pem",
        'privkey'         => "${le_live}/privkey.pem",
        'p12_path'        => $p12_path,
        'password_file'   => $password_file,
        'prefs_file'      => $prefs_file,
        'restart_command' => $restart_command,
        'plex_user'       => $plexmediaserver::plex_user,
    }),
  }

  # Rebuild the p12 (and restart Plex) whenever the certificate changes.
  exec { 'plex-generate-p12':
    command     => $deploy_script,
    refreshonly => true,
    path        => ['/usr/local/bin', '/usr/bin', '/bin'],
    subscribe   => [Letsencrypt::Certonly['console-services'], File[$deploy_script], File[$password_file]],
    require     => File[$deploy_script, $password_file],
  }
}
