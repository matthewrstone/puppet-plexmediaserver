# class plexmediaserver::secure
# Configures Plex Media Server to use Let's Encrypt certificates for secure access.
#
# @param dns_provider
#   DNS provider to use for domain validation. Required if letsencrypt is true.
# @param dns_provider_token
#   API token for the DNS provider. Required if letsencrypt is true.
# @param dns_provider_email
#   Email address associated with the DNS provider account. Required if letsencrypt is true
#   and the DNS provider requires an email for API access.
# @param domain_name
#   Domain name that points to the Plex Media Server. Required if letsencrypt is true.
# @param domain_contact_email
#   Email address to use for domain registration. Required if letsencrypt is true and the
#   DNS provider requires an email for domain registration.
# @param cert_dir
#   Directory where Plex Media Server expects its SSL certificates. Required if letsencrypt is true.
# @param letsencrypt_conf_dir
#   Directory where Let's Encrypt configuration and certificates will be stored. Required if letsencrypt is true.
#
class plexmediaserver::secure (
  String $dns_provider,
  Sensitive[String] $dns_provider_token,
  String $domain_name,
  String $cert_dir,
  String $letsencrypt_conf_dir,
  Optional[String] $dns_provider_email  = undef,
  Optional[String] $domain_contact_email = undef,
) {
  case $plexmediaserver::service_manager_real {
    'supervisord': {
      $stop_command  = '/usr/bin/supervisorctl stop plexmediaserver'
      $start_command = '/usr/bin/supervisorctl start plexmediaserver'
    }
    default: {
      $stop_command  = '/bin/systemctl stop plexmediaserver'
      $start_command = '/bin/systemctl start plexmediaserver'
    }
  }

  class { 'letsencrypt':
    package_ensure => latest,
    config         => { email  => $dns_provider_email, },
    config_dir     => $letsencrypt_conf_dir,
  }

  class { 'letsencrypt::plugin::dns_cloudflare':
    api_token      => $dns_provider_token.unwrap,
    manage_package => true,
    require        => Class['letsencrypt'],
  }
  $cron_success = $plexmediaserver::configure_ssl ? {
    true    => '/usr/local/bin/plexmediaserver-deploy-cert.sh',
    default => $start_command,
  }

  letsencrypt::certonly { 'console-services':
    domains              => [$domain_name],
    plugin               => $dns_provider,
    manage_cron          => true,
    cron_hour            => [0,12],
    cron_minute          => '30',
    cron_before_command  => $stop_command,
    cron_success_command => $cron_success,
    require              => Class['plexmediaserver'],
    cron_output          => 'suppress',
  }
}
