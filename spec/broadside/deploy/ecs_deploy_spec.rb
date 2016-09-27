require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'full configuration'

  let(:valid_options) do
    {
#      tag: 'NEW_TEST_TAG',
      target: :TEST_TARGET,
#      scale: 100,
 #     rollback: 100,
  #    instance: 100,
   #   cmd: ['echo', 'TEST']
    }
  end

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

  let(:ecs_stub) { Aws::ECS::Client.new(region: config.aws.region, credentials: config.aws.credentials, stub_responses: true) }
  let(:deploy) { described_class.new(valid_options) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end
end
