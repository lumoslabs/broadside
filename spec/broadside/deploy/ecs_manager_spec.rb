require 'spec_helper'

# Hitting the stubbed Aws::ECS::Client object will validate the request format

describe Broadside::EcsManager do
  let(:service_name) { 'service' }
  let(:cluster) { 'cluster' }
  let(:name) { 'job' }

  let(:ecs_stub) do
    Aws::ECS::Client.new(
      region: Broadside.config.aws.region,
      credentials: Aws::Credentials.new('access', 'secret'),
      stub_responses: true
    )
  end

  before(:each) { Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'create_service' do
    expect { described_class.create_service(cluster, service_name) }.to_not raise_error
  end

  it 'list services' do
    expect { described_class.list_services(cluster) }.to_not raise_error
  end

  it 'get_task_arns' do
    expect { described_class.get_task_arns(cluster, name) }.to_not raise_error
  end

  it 'get_task_definition_arns' do
    expect { described_class.get_task_definition_arns(name) }.to_not raise_error
    expect { described_class.get_latest_task_definition_arn(name) }.to_not raise_error
  end

  it 'get_latest_task_definition' do
    expect(described_class.get_latest_task_definition(name)).to be_nil
  end
end
