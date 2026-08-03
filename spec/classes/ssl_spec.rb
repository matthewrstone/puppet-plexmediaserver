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
      end

      context 'without configure_ssl (default)' do
        it { is_expected.not_to contain_class('plexmediaserver::ssl') }
      end
    end
  end
end
