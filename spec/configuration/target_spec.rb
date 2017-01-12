require 'spec_helper'

describe Broadside::Target do
  shared_examples 'valid_configuration?' do |succeeds, config_hash|
    let(:target) { described_class.new(config_hash) }

    it 'validates target configuration' do
      if succeeds
        expect { target.send(:validate_targets!) }.to_not raise_error
      else
        expect {  target.send(:validate_targets!) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#validate_targets!' do
    include_examples 'valid_configuration?', false, scale: 1.1
    include_examples 'valid_configuration?', false, scale: '1'
    include_examples 'valid_configuration?', false, scale: nil
    include_examples 'valid_configuration?', true,  scale: 100

    include_examples 'valid_configuration?', false, env_files: nil
    include_examples 'valid_configuration?', true,  env_files: '.env.test'

    include_examples 'valid_configuration?', false, command: 'bundle exec rails s'
    include_examples 'valid_configuration?', true,  command: nil
    include_examples 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']

    include_examples 'valid_configuration?', true,  predeploy_commands: [['bundle', 'exec', 'rake' 'db:migrate']]
    include_examples 'valid_configuration?', true,  predeploy_commands: [
      ['bundle', 'exec', 'rake' 'db:migrate'],
      ['bundle', 'exec', 'rake' 'assets:precompile']
    ]
    include_examples 'valid_configuration?', true,  predeploy_commands: nil
    include_examples 'valid_configuration?', false,  predeploy_commands: ['bundle', 'exec', 'rake' 'db:migrate']
    include_examples 'valid_configuration?', false,  predeploy_commands: 'bundle exec rake db:migrate'

    include_examples 'valid_configuration?', false, command: 'bundle exec rails s'
    include_examples 'valid_configuration?', true,  command: nil
    include_examples 'valid_configuration?', true,  command: ['bundle', 'exec', 'resque:work']


    include_examples 'valid_configuration?', true,  env_files: ['env_file1', 'env_file2']
  end

  describe '#load_env_vars!' do
    context 'with a single environment file' do
      let(:config) do
        config = described_class.new
        config.targets = {
          test_target: {
            env_files: File.join(FIXTURES_PATH, 'sample_dotenv')
          }
        }
        config.target = :test_target
        config
      end
      let(:expected_env_vars) do
        [{'name'=>'TEST_KEY1', 'value'=>'TEST_VALUE1'},
         {'name'=>'TEST_KEY2', 'value'=>'TEST_VALUE2'}]
      end

      it 'loads environment variables from a file' do
        expect(config.env_vars).to eq(nil)
        config.load_env_vars!
        expect(config.env_vars).to eq(expected_env_vars)
      end
    end

    context 'with multiple environment files' do
      let(:config) do
        config = described_class.new
        config.targets = {
          test_target: {
            env_files: [File.join(FIXTURES_PATH, 'sample_dotenv_a'), File.join(FIXTURES_PATH, 'sample_dotenv_b')]
          }
        }
        config.target = :test_target
        config
      end
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
        expect(config.env_vars).to eq(nil)
        config.load_env_vars!
        expect(config.env_vars).to eq(expected_env_vars)
      end
    end
  end
end
