require 'spec_helper'

describe Broadside::EcsDeploy do
  let(:deploy_config) do
    {
      scale: 1,
      command: ['java', 'barf', 'com.lumoslabs.events.kstream.streams.GameSaveAsJsonBlob'],
      env_file: '.env.production',
    }
  end

  let(:deploy_with_service_config) do
    deploy_config.merge(
      service: {
        deployment_configuration: {
          minimum_healthy_percent: 0.5,
        }
      }
    )
  end

  let(:deploy_with_task_definition_config) do
    deploy_config.merge(
      task_definition: {
        container_definitions: [
          {
            cpu: 1,
            memory: 2000,
          }
        ]
      }
    )
  end

  let(:ecs) { Aws::ECS::Client.new(region: config.aws.region, credentials: config.aws.credentials, stub_responses: true) }
  let(:deploy) { described_class.new(deploy_config) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end
end
