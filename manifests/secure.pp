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
class plexmediaserver::secure (
  String $dns_provider,
  String $dns_provider_token,
  String $domain_name,
  String $cert_dir,
  String $letsencrypt_conf_dir,
  Optional[String] $dns_provider_email,
  Optional[String] $domain_contact_email,
) {
  class { 'letsencrypt':
    package_ensure => latest,
    config         => { email  => $dns_provider_email, },
    config_dir     => $letsencrypt_conf_dir,
  }
  letsencrypt::certonly { 'console-services':
    domains              => [$domain_name],
    plugin               => $dns_provider,
    manage_cron          => true,
    cron_hour            => [0,12],
    cron_minute          => '30',
    cron_before_command  => '/bin/systemctl stop plexmediaserver',
    cron_success_command => '/bin/systemctl start plexmediaserver',
    require              => Class['plexmediaserver'],
    cron_output          => 'suppress',
  }
}
