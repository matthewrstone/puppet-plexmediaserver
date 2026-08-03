require 'spec_helper'

describe 'plexmediaserver::secure' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:params) do
        {
          'dns_provider'         => 'dns-cloudflare',
          'dns_provider_token'   => 'token',
          'domain_name'          => 'plex.example.com',
          'cert_dir'             => '/var/lib/plexmediaserver/Resources/SSL',
          'letsencrypt_conf_dir' => '/etc/letsencrypt',
          'dns_provider_email'   => 'me@example.com',
          'domain_contact_email' => 'me@example.com',
        }
      end

      context 'on systemd' do
        let(:facts) { os_facts.merge('virtual' => 'kvm') }
        let(:pre_condition) { "class { 'plexmediaserver': }" }

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_letsencrypt__certonly('console-services')
            .with_cron_before_command(%r{systemctl stop plexmediaserver})
            .with_cron_success_command(%r{systemctl start plexmediaserver})
        end
      end

      context 'on supervisord' do
        let(:facts) { os_facts.merge('virtual' => 'lxc') }
        let(:pre_condition) { "class { 'plexmediaserver': }" }

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_letsencrypt__certonly('console-services')
            .with_cron_before_command(%r{supervisorctl stop plexmediaserver})
            .with_cron_success_command(%r{supervisorctl start plexmediaserver})
        end
      end
    end
  end
end
