require 'spec_helper'

describe 'plexmediaserver' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge('virtual' => 'kvm') }

      context 'with configure_ssl but without use_letsencrypt' do
        let(:params) do
          {
            'configure_ssl'       => true,
            'ssl_pkcs12_password' => sensitive('p12pass'),
          }
        end

        it { is_expected.to compile.and_raise_error(%r{requires use_letsencrypt}) }
      end

      context 'with configure_ssl and use_letsencrypt but without ssl_pkcs12_password' do
        let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
        let(:params) do
          {
            'use_letsencrypt' => true,
            'configure_ssl'   => true,
          }
        end

        it { is_expected.to compile.and_raise_error(%r{ssl_pkcs12_password}) }
      end

      context 'with configure_ssl and use_letsencrypt' do
        let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
        let(:params) do
          {
            'use_letsencrypt'     => true,
            'configure_ssl'       => true,
            'ssl_pkcs12_password' => sensitive('p12pass'),
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('plexmediaserver::ssl') }
        it do
          is_expected.to contain_file('/var/lib/plexmediaserver/Resources/SSL')
            .with_ensure('directory')
        end
        it do
          is_expected.to contain_file('/usr/local/bin/plexmediaserver-deploy-cert.sh')
            .with_ensure('file')
            .with_mode('0755')
        end
        it do
          is_expected.to contain_file('/var/lib/plexmediaserver/Resources/SSL/.p12_password')
            .with_ensure('file')
            .with_mode('0600')
            .with_show_diff(false)
        end
        it do
          is_expected.to contain_exec('plex-generate-p12')
            .with_refreshonly(true)
            .that_subscribes_to('Letsencrypt::Certonly[console-services]')
        end
        it do
          is_expected.to contain_augeas('plex-ssl-preferences')
            .with_incl('/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml')
            .with_lens('Xml.lns')
            .with_onlyif('match . size > 0')
        end
        it 'guards on Preferences.xml existing and sets the cert attributes' do
          aug = catalogue.resource('Augeas', 'plex-ssl-preferences')
          expect(aug[:onlyif]).to eq('match . size > 0')
          expect(aug[:changes].join("\n")).to match(%r{customCertificatePath})
          expect(aug[:changes].join("\n")).to match(%r{customCertificateDomain})
          expect(aug[:changes].join("\n")).to match(%r{secureConnections})
        end
        it { is_expected.to contain_augeas('plex-ssl-preferences').that_notifies('Exec[plex-generate-p12]') }
        it 'routes a successful renewal through the deploy script (rebuild p12 + restart) instead of a bare start' do
          is_expected.to contain_letsencrypt__certonly('console-services')
            .with_cron_success_command('/usr/local/bin/plexmediaserver-deploy-cert.sh')
        end
        it do
          is_expected.to contain_file('/usr/local/bin/plexmediaserver-deploy-cert.sh')
            .with_content(%r{systemctl restart plexmediaserver})
        end
      end

      context 'without configure_ssl (default)' do
        it { is_expected.not_to contain_class('plexmediaserver::ssl') }
      end
    end

    context "on #{os} (supervisord)" do
      let(:facts) { os_facts.merge('virtual' => 'lxc') }

      context 'with configure_ssl and use_letsencrypt' do
        let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
        let(:params) do
          {
            'use_letsencrypt'     => true,
            'configure_ssl'       => true,
            'ssl_pkcs12_password' => sensitive('p12pass'),
          }
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_file('/usr/local/bin/plexmediaserver-deploy-cert.sh')
            .with_content(%r{supervisorctl restart plexmediaserver})
        end
      end
    end
  end
end
