require 'spec_helper'

describe Broadside do
  include_context 'deploy configuration'

  describe '#load_config' do
    it 'calls load for both the system and app config files' do
      expect(Broadside).to receive(:load).with(system_config_path).ordered
      expect(Broadside).to receive(:load).with(app_config_path).ordered
      expect(Broadside.config).to receive(:valid?).and_return(true).ordered
      Broadside.load_config(app_config_path)
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
