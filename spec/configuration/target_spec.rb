require 'spec_helper'

describe Broadside::Target do
  shared_examples 'valid_configuration?' do |succeeds, config_hash|
    let(:valid_options) { { scale: 100, env_files: File.join(FIXTURES_PATH, 'sample_dotenv') } }
    let(:target) { described_class.new('tarbaby_target', valid_options.merge(config_hash) )}

    it 'validates target configuration' do
      if succeeds
        expect { target }.to_not raise_error
      else
        expect { target }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#validate_targets!' do
    it_behaves_like 'valid_configuration?', false, scale: 1.1
    it_behaves_like 'valid_configuration?', false, scale: '1'
    it_behaves_like 'valid_configuration?', false, scale: nil
    it_behaves_like 'valid_configuration?', true,  scale: 100

    it_behaves_like 'valid_configuration?', false, env_files: nil
    it_behaves_like 'valid_configuration?', true,  {}

    it_behaves_like 'valid_configuration?', false, command: 'bundle exec rails s'
    it_behaves_like 'valid_configuration?', true,  command: nil
    it_behaves_like 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']

    it_behaves_like 'valid_configuration?', true,   predeploy_commands: nil
    it_behaves_like 'valid_configuration?', false,  predeploy_commands: Broadside::PredeployCommands::RAKE_DB_MIGRATE
    it_behaves_like 'valid_configuration?', false,  predeploy_commands: 'bundle exec rake db:migrate'
    it_behaves_like 'valid_configuration?', true,   predeploy_commands: [Broadside::PredeployCommands::RAKE_DB_MIGRATE]
    it_behaves_like 'valid_configuration?', true,   predeploy_commands: [
      Broadside::PredeployCommands::RAKE_DB_MIGRATE,
      ['bundle', 'exec', 'rake' 'assets:precompile']
    ]

    it_behaves_like 'valid_configuration?', false, command: 'bundle exec rails s'
    it_behaves_like 'valid_configuration?', true,  command: nil
    it_behaves_like 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']
  end

  describe '#load_env_vars!' do
    let(:valid_options) { { scale: 100, env_files: env_files } }
    let(:target) { described_class.new('tarbaby_target', valid_options) }

    context 'with a single environment file' do
      let(:env_files) { File.join(FIXTURES_PATH, 'sample_dotenv') }
      let(:expected_env_vars) do
        [
          { 'name' => 'TEST_KEY1', 'value' => 'TEST_VALUE1'},
          { 'name' => 'TEST_KEY2', 'value' => 'TEST_VALUE2'}
        ]
      end

      it 'loads environment variables from a file' do
        expect(target.env_vars).to eq(expected_env_vars)
      end
    end

    context 'with multiple environment files' do
      let(:env_files) { [File.join(FIXTURES_PATH, 'sample_dotenv_a'), File.join(FIXTURES_PATH, 'sample_dotenv_b')] }
      let(:expected_env_vars) do
        [
          {'name'=>'SHARED_KEY_1', 'value'=>'SHARED_VALUE_1b'},
          {'name'=>'SHARED_KEY_2', 'value'=>'SHARED_VALUE_2b'},
          {'name'=>'UNIQUE_KEY_1a', 'value'=>'UNIQUE_VALUE_1a'},
          {'name'=>'UNIQUE_KEY_2a', 'value'=>'UNIQUE_VALUE_1a'},
          {'name'=>'UNIQUE_KEY_1b', 'value'=>'UNIQUE_VALUE_1b'},
          {'name'=>'UNIQUE_KEY_2b', 'value'=>'UNIQUE_VALUE_1b'},
        ]
      end

      it 'loads the last environment file with highest precedence' do
        expect(target.env_vars).to eq(expected_env_vars)
      end
    end
  end
end
