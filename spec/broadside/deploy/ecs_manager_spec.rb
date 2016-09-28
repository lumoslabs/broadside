require 'spec_helper'

describe Broadside::EcsManager do
  let(:service_name) { 'service' }
  let(:cluster) { 'cluster' }

  let(:ecs_stub) do
    Aws::ECS::Client.new(
      region: Broadside.config.aws.region,
      credentials: Aws::Credentials.new('access', 'secret'),
      stub_responses: true
    )
  end

  before(:each) { Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'should be able to create a service' do
    expect { described_class.create_service(cluster, service_name) }.to_not raise_error
  end
end
