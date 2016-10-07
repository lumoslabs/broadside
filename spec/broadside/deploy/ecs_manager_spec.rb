require 'spec_helper'

# Hitting the stubbed Aws::ECS::Client object will validate the request format

describe Broadside::EcsManager do
  let(:service_name) { 'service' }
  let(:cluster) { 'cluster' }
  let(:name) { 'job' }
  let(:task_definition_arns) { ["arn:task-definition/task:1", "arn:task-definition/other_task:1" ] }
  let(:stub_task_definition_responses) do
    [
      { task_definition_arns: [task_definition_arns[0]], next_token: 'MzQ3N' },
      { task_definition_arns: [task_definition_arns[1]] }
    ]
  end

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

  it 'list_services' do
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

  context 'run command' do
    let(:task_arn) { "arn:aws:ecs:us-east-1:<aws_account_id>:task/a9f21ea7-c9f5-44b1-b8e6-b31f50ed33c0" }

    before do
      ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_responses)
      ecs_stub.stub_responses(:run_task, { tasks: [{ task_arn: task_arn }] })
    end

    it 'runs commands' do
      expect(described_class.run_task(cluster, name, %w(bundle exec rake db:migrate))).to eq(task_arn)
    end
  end

  context 'all_results' do
    before do
      ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_responses)
    end

    it 'can pull multipage results' do
      expect(described_class.get_task_definition_arns('task')).to eq(task_definition_arns)
    end
  end
end
