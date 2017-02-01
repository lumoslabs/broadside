require 'spec_helper'

describe Broadside do
  describe '#load_config' do
    let(:system_config_path) { File.join(FIXTURES_PATH, 'broadside_system_example.conf.rb') }
    let(:app_config_path) { File.join(FIXTURES_PATH, 'broadside_app_example.conf.rb') }
    let(:ssh_system_user) { { user: 'system-default-user' } }
    let(:ssh_app_user)    { { user: 'app-default-user' } }

    before do
      stub_const('Broadside::USER_CONFIG_FILE', system_config_path)
      expect(Broadside.config).to receive(:verify)
    end

    it 'calls load for both the system and app config files' do
      expect(Broadside).to receive(:load).with(system_config_path)
      expect(Broadside).to receive(:load).with(app_config_path)
      Broadside.load_config(app_config_path)
    end

    it 'loads the app-specific config with a higher precedence than the system-level config' do
      Broadside.load_config(app_config_path)
      expect(Broadside.config.ssh).to eq(ssh_app_user)
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
