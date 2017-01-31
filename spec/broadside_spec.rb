require 'spec_helper'

describe Broadside do
  describe '#load_config' do
    let(:system_config_path) { File.join(FIXTURES_PATH, 'broadside_system_example.conf.rb') }
    let(:app_config_path) { File.join(FIXTURES_PATH, 'broadside_app_example.conf.rb') }

    context 'system config loading precedence' do
      before do
        allow(Broadside).to receive(:load)
        # stub out verify from erroring since load is stubbed
        allow(Broadside.config).to receive(:verify)
        stub_const('Broadside::USER_CONFIG_FILE', system_config_path)
      end

      it 'loads a system-level config file and passed in config file' do
        Broadside.load_config(app_config_path)
        expect(Broadside).to have_received(:load).with(system_config_path)
        expect(Broadside).to have_received(:load).with(app_config_path)
      end
    end

    context 'with a system config' do
      let(:ssh_system_user) { { user: 'system-default-user' } }
      let(:ssh_app_user)    { { user: 'app-default-user' } }

      it 'loads the app-specific config with a higher precedence than the system-level config' do
        stub_const('Broadside::USER_CONFIG_FILE', system_config_path)
        expect(Broadside.config).to receive(:verify)
        Broadside.load_config(app_config_path)
        expect(Broadside.config.ssh).to eq(ssh_app_user)
      end
    end
  end

  describe '#reset!' do
    it 'discards the existing configuration' do
      cfg = Broadside.config
      expect(cfg).to eq(Broadside.config)
      Broadside.reset!
      expect(cfg).not_to eq(Broadside.config)
    end
  end
end
