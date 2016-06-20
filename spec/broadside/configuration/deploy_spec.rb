require 'spec_helper'

module Broadside
  class Configuration
    describe DeployConfig do
      shared_examples 'valid_configuration?' do |succeeds, sym|
        let(:config) do
          config = Broadside::Configuration::DeployConfig.new
          config.targets = {
            test_target: {
              scale: 1,
              env_file: 'some_environment_file'
            }
          }
          config.target = :test_target
          config
        end
        let(:sym) { sym }
        let(:succeeds) { succeeds }
        it 'validates deploy_target configuration' do
          config.targets[:test_target].merge!(sym)
          expect { config.validate_targets! }.to_not raise_error if succeeds
          expect { config.validate_targets! }.to raise_error(Broadside::Error) unless succeeds
        end
      end

      describe '#validate_targets!' do
        include_examples 'valid_configuration?', false, scale: 1.1
        include_examples 'valid_configuration?', false, scale: '1'
        include_examples 'valid_configuration?', false, scale: nil
        include_examples 'valid_configuration?', true,  scale: 100

        include_examples 'valid_configuration?', false, env_file: nil
        include_examples 'valid_configuration?', true,  env_file: '.env.test'

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
      end
    end
  end
end
