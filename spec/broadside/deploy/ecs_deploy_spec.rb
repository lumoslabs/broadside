require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'full configuration'

  let(:valid_options) { { target: :TEST_TARGET } }

  let(:service_config) do
    {
      service: {
        deployment_configuration: {
          minimum_healthy_percent: 0.5,
        }
      }
    }
  end

  let(:task_definition_config) do
    {
      task_definition: {
        container_definitions: [
          {
            cpu: 1,
            memory: 2000,
          }
        ]
      }
    }
  end

  let(:ecs_stub) { Aws::ECS::Client.new(region: Broadside.config.aws.region, credentials: Broadside.config.aws.credentials, stub_responses: true) }
  let(:deploy) { described_class.new(valid_options) }

  before(:each) { deploy.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end

  context 'bootstrap' do
    it 'fails without service_config' do
      expect { deploy.bootstrap }.to raise_error(/Service doesn't exist and cannot be created/)
    end

    it 'fails without task_definition_config' do
      deploy.service_config = service_config
      expect { deploy.bootstrap }.to raise_error(/X doesn't exist and cannot be created/)
    end
  end
end
