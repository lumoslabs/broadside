shared_context 'ecs stubs' do
  let(:api_request_log) { [] }
  let(:ecs_stub) { build_stub_aws_client(Aws::ECS::Client, api_request_log) }
  let(:ec2_stub) { build_stub_aws_client(Aws::EC2::Client, api_request_log) }

  before(:each) do
    Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub)
    Broadside::EcsManager.instance_variable_set(:@ec2_client, ec2_stub)
  end
end

shared_context 'with a running service' do
  include_context 'ecs stubs'

  before(:each) do
    ecs_stub.stub_responses(:describe_services, stub_service_response)
  end

  let(:stub_service_response) do
    {
      services: [
        {
          service_name: test_target.to_s,
          service_arn: "#{arn}:service/#{test_target}",
          deployments: [{ desired_count: 1, running_count: 1 }]
        }
      ],
      failures: []
    }
  end
end

shared_context 'with a task_definition' do
  include_context 'ecs stubs'
  
  let(:task_definition_arn) { "#{arn}:task-definition/#{test_target}:1" }
  let(:stub_task_definition_response) { { task_definition_arns: [task_definition_arn] } }
  let(:stub_describe_task_definition_response) do
    {
      task_definition: {
        task_definition_arn: task_definition_arn,
        container_definitions: [
          {
            name: family
          }
        ],
        family: family
      }
    }
  end

  before(:each) do
    ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_response)
    ecs_stub.stub_responses(:describe_task_definition, stub_describe_task_definition_response)
  end
end
