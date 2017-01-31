require 'spec_helper'

describe Broadside::Target do
  include_context 'deploy configuration'

  let(:target_name) { 'tarbaby_target' }

  shared_examples 'valid_configuration?' do |succeeds, config_hash|
    let(:valid_options) { { scale: 100 } }
    let(:target) { described_class.new(target_name, valid_options.merge(config_hash) )}

    it 'validates target configuration' do
      if succeeds
        expect { target }.to_not raise_error
      else
        expect { target }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#validate_targets!' do
    it_behaves_like 'valid_configuration?', true, {}

    it_behaves_like 'valid_configuration?', false, scale: 1.1
    it_behaves_like 'valid_configuration?', false, scale: nil
    it_behaves_like 'valid_configuration?', true,  scale: 100

    it_behaves_like 'valid_configuration?', true,  env_files: nil
    it_behaves_like 'valid_configuration?', true,  env_files: 'file'
    it_behaves_like 'valid_configuration?', true,  env_files: ['file', 'file2']

    it_behaves_like 'valid_configuration?', true,  command: nil
    it_behaves_like 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']
    it_behaves_like 'valid_configuration?', false, command: 'bundle exec rails s'

    it_behaves_like 'valid_configuration?', false, not_a_param: 'foo'

    it_behaves_like 'valid_configuration?', true,  predeploy_commands: nil
    it_behaves_like 'valid_configuration?', false, predeploy_commands: Broadside::PredeployCommands::RAKE_DB_MIGRATE
    it_behaves_like 'valid_configuration?', false, predeploy_commands: 'bundle exec rake db:migrate'
    it_behaves_like 'valid_configuration?', true,  predeploy_commands: [Broadside::PredeployCommands::RAKE_DB_MIGRATE]
    it_behaves_like 'valid_configuration?', true,  predeploy_commands: [
      Broadside::PredeployCommands::RAKE_DB_MIGRATE,
      ['bundle', 'exec', 'rake' 'assets:precompile']
    ]
  end

  describe '#env_vars' do
    let(:valid_options) { { scale: 1, env_files: env_files } }
    let(:target) { described_class.new(target_name, valid_options) }

    shared_examples 'successfully loaded env_files' do
      it 'loads environment variables from a file' do
        expect(target.env_vars).to eq(expected_env_vars)
      end
    end

    context 'with a single environment file' do
      let(:env_files) { dot_env_file }
      let(:expected_env_vars) do
        [
          { 'name' => 'TEST_KEY1', 'value' => 'TEST_VALUE1'},
          { 'name' => 'TEST_KEY2', 'value' => 'TEST_VALUE2'}
        ]
      end

      it_behaves_like 'successfully loaded env_files'
    end

    context 'with multiple environment files' do
      let(:env_files) { [dot_env_file, dot_env_file + '.override'] }
      let(:expected_env_vars) do
        [
          { 'name' => 'TEST_KEY1', 'value' => 'TEST_VALUE1' },
          { 'name' => 'TEST_KEY2', 'value' => 'TEST_VALUE_OVERRIDE'},
          { 'name' => 'TEST_KEY3', 'value' => 'TEST_VALUE3'}
        ]
      end

      it_behaves_like 'successfully loaded env_files'
    end
  end
end
