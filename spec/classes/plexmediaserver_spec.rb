require 'spec_helper'

describe 'plexmediaserver' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge('virtual' => 'kvm') }

      context 'with defaults (systemd on a VM)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('plexmediaserver').with_ensure('latest') }
        it do
          is_expected.to contain_service('plexmediaserver')
            .with_ensure('running')
            .with_enable(true)
        end
        it { is_expected.not_to contain_exec('plex-supervisor-update') }
        it { is_expected.not_to contain_package('supervisor') }
        it { is_expected.to contain_class('plexmediaserver::install').that_comes_before('Class[plexmediaserver::config]') }
        it { is_expected.to contain_class('plexmediaserver::config').that_notifies('Class[plexmediaserver::service]') }
        it { is_expected.to contain_class('plexmediaserver::service') }

        case os_facts[:os]['family']
        when 'RedHat'
          it { is_expected.to contain_yumrepo('Plex.tv') }
        when 'Debian'
          it { is_expected.to contain_exec('import-plex-gpg-key') }
          it { is_expected.to contain_apt__source('plex') }
        end
      end

      context 'with an invalid service_manager' do
        let(:params) { { 'service_manager' => 'runit' } }

        it { is_expected.to compile.and_raise_error(%r{service_manager}) }
      end

      context 'in an LXC container (auto-detected supervisord)' do
        let(:facts) { os_facts.merge('virtual' => 'lxc') }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('plexmediaserver') }
        it { is_expected.to contain_package('supervisor').with_ensure('present') }
        it { is_expected.not_to contain_service('plexmediaserver') }
        it do
          is_expected.to contain_exec('plex-supervisor-update')
            .with_refreshonly(true)
            .with_command(['/usr/bin/supervisorctl', 'update'])
        end
        it 'writes a supervisor program config that runs Plex as the plex user' do
          program_config = case os_facts[:os]['family']
                           when 'RedHat'
                             '/etc/supervisord.d/plexmediaserver.ini'
                           else
                             '/etc/supervisor/conf.d/plexmediaserver.conf'
                           end

          is_expected.to contain_file(program_config)
            .with_content(%r{command=/usr/lib/plexmediaserver/Plex Media Server})
            .with_content(%r{user=plex})
            .with_content(%r{stopasgroup=true})
            .with_content(%r{killasgroup=true})
        end
      end

      context 'with an explicit supervisord override on a VM' do
        let(:facts) { os_facts.merge('virtual' => 'kvm') }
        let(:params) { { 'service_manager' => 'supervisord' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('supervisor') }
        it { is_expected.not_to contain_service('plexmediaserver') }
      end
    end
  end
end
