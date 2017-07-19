require 'spec_helper'

describe Broadside do
  include_context 'deploy configuration'

  it 'should be able to display the help menu' do
    silence_warnings do
      exit_value = system('bundle exec broadside --help >/dev/null')
      expect(exit_value).to be_truthy
    end
  end

  describe '#load_config_file' do
    it 'calls load for both the system and app config files' do
      expect(Broadside).to receive(:load).with(system_config_path).ordered
      expect(Broadside).to receive(:load).with(app_config_path).ordered
      Broadside.load_config_file(app_config_path)
    end
  end

  describe '#reset!' do
    it 'discards the existing configuration' do
      current_config = Broadside.config
      expect(current_config).to eq(Broadside.config)
      Broadside.reset!
      expect(current_config).not_to eq(Broadside.config)
    end
  end
end
