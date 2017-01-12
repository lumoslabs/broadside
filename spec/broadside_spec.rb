require 'spec_helper'

describe Broadside do
  describe '#load_config' do
    let(:bad_path) { 'path_does_not_exist' }
    let(:system_config_path) { File.join(FIXTURES_PATH, 'broadside_system_example.conf.rb') }
    let(:app_config_path) { File.join(FIXTURES_PATH, 'broadside_app_example.conf.rb') }

    it 'loads a system-level config file' do
      allow(Broadside).to receive(:load)
      # stub out verify from erroring since load is stubbed
      allow(Broadside.config).to receive(:verify)
      stub_const('Broadside::SYSTEM_CONFIG_FILE', system_config_path)
      Broadside.load_config(app_config_path)
      expect(Broadside).to have_received(:load).with(system_config_path)
    end

    it 'does not load a system-level config file if it does not exist' do
      allow(Broadside).to receive(:load)
      # stub out verify from erroring since load is stubbed
      allow(Broadside.config).to receive(:verify)
      stub_const('Broadside::SYSTEM_CONFIG_FILE', bad_path)
      Broadside.load_config(app_config_path)
      expect(Broadside).not_to have_received(:load).with(bad_path)
    end

    it 'loads the application-specific config file passed in' do
      allow(Broadside).to receive(:load)
      # stub out verify from erroring since load is stubbed
      allow(Broadside.config).to receive(:verify)
      Broadside.load_config(app_config_path)
      expect(Broadside).to have_received(:load).with(app_config_path)
    end

    let(:ssh_system_user) { { user: 'system-default-user' } }
    let(:ssh_app_user)    { { user: 'app-default-user' } }

    it 'loads the app-specific config with a higher precedence than the system-level config' do
      Broadside.load_config(app_config_path)
      expect(Broadside.config.ssh).to eq(ssh_app_user)
      expect(Broadside.config.ssh).not_to eq(ssh_system_user)
    end

    it 'verfies the configuration after loading' do
      expect(Broadside.config).to receive(:verify)
      Broadside.load_config(app_config_path)
    end
  end

  describe '#reset!' do
    it 'Discards the existing configuration' do
      cfg = Broadside.config
      expect(cfg).to eq(Broadside.config)
      Broadside.reset!
      expect(cfg).not_to eq(Broadside.config)
    end
  end
end
