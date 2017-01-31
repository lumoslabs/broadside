require 'spec_helper'

describe Broadside::Target do
  let(:sample_dotenv) { File.join(FIXTURES_PATH, '.env.rspec') }

  shared_examples 'valid_configuration?' do |succeeds, config_hash|
    let(:valid_options) { { scale: 100, env_files: sample_dotenv } }
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

    it_behaves_like 'valid_configuration?', true,  command: nil
    it_behaves_like 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']
    it_behaves_like 'valid_configuration?', false, command: 'bundle exec rails s'

    it_behaves_like 'valid_configuration?', true,   predeploy_commands: nil
    it_behaves_like 'valid_configuration?', false,  predeploy_commands: Broadside::PredeployCommands::RAKE_DB_MIGRATE
    it_behaves_like 'valid_configuration?', false,  predeploy_commands: 'bundle exec rake db:migrate'
    it_behaves_like 'valid_configuration?', true,   predeploy_commands: [Broadside::PredeployCommands::RAKE_DB_MIGRATE]
    it_behaves_like 'valid_configuration?', true,   predeploy_commands: [
      Broadside::PredeployCommands::RAKE_DB_MIGRATE,
      ['bundle', 'exec', 'rake' 'assets:precompile']
    ]
  end

  describe '#load_env_vars!' do
    let(:valid_options) { { scale: 100, env_files: env_files } }
    let(:target) { described_class.new('tarbaby_target', valid_options) }

    before do
      target.load_env_vars!
    end

    context 'with a single environment file' do
      let(:env_files) { sample_dotenv }
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
      let(:env_files) { [sample_dotenv, sample_dotenv + '.override'] }
      let(:expected_env_vars) do
        [
          { 'name' => 'TEST_KEY1', 'value' => 'TEST_VALUE1' },
          { 'name' => 'TEST_KEY2', 'value' => 'TEST_VALUE_OVERRIDE'},
          { 'name' => 'TEST_KEY3', 'value' => 'TEST_VALUE3'}
        ]
      end

      it 'loads the last environment file with highest precedence' do
        expect(target.env_vars).to eq(expected_env_vars)
      end
    end
  end
end
