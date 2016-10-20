require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'full configuration'

  let(:app_name) { 'TEST_APP' }
  let(:task_name) { 'TEST_TARGET' }
  let(:family) { "#{app_name}_#{task_name}" }
  let(:valid_options) { { target: task_name.to_sym } }
  let(:deploy) { described_class.new(valid_options) }

  let(:api_request_log) { [] }

  let(:ecs_stub) do
    requests = api_request_log
    client = Aws::ECS::Client.new(
      region: Broadside.config.aws.region,
      credentials: Aws::Credentials.new('access', 'secret'),
      stub_responses: true
    )

    client.handle do |context|
      requests << { context.operation_name => context.params }
      @handler.call(context)
    end

    client
  end

  let(:desired_count) { 2 }
  let(:minimum_healthy_percent) { 40 }
  let(:service_config) do
    {
      desired_count: desired_count,
      deployment_configuration: {
        minimum_healthy_percent: minimum_healthy_percent,
      }
    }
  end

  let(:cpu) { 1 }
  let(:memory) { 2000 }
  let(:task_definition_config) do
    {
      container_definitions: [
        {
          cpu: cpu,
          memory: memory,
        }
      ]
    }
  end

  before(:each) { Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end

  context 'bootstrap' do
    it 'fails without task_definition_config' do
      expect { deploy.bootstrap }.to raise_error(//)
    end

    it 'fails without service_config' do
      deploy.deploy_config.task_definition_config = task_definition_config

      expect { deploy.bootstrap }.to raise_error(/Service doesn't exist and no :service_config/)
    end

    it 'succeeds' do
      deploy.deploy_config.service_config = service_config
      deploy.deploy_config.task_definition_config = task_definition_config

      expect { deploy.bootstrap }.to_not raise_error
    end
  end

  context 'deploy' do
    it 'fails without an existing service' do
      expect { deploy.deploy }.to raise_error(/No service for #{family}!/)
    end

    context 'with an existing service' do
      let(:arn) { 'arn:aws:ecs:us-east-1:1234' }
      let(:existing_service) do
        {
          service_name: task_name,
          service_arn: "#{arn}:service/#{task_name}",
          deployments: [{ desired_count: 1, running_count: 1 }]
        }
      end
      let(:stub_service_response) { { services: [existing_service], failures: [] } }

      before(:each) do
        ecs_stub.stub_responses(:describe_services, stub_service_response)
      end

      it 'fails without an existing task_definition' do
        expect { deploy.deploy }.to raise_error(/No task definition for/)
      end

      context 'with an existing task definition' do
        let(:task_definition_arn) { "#{arn}:task-definition/#{task_name}:1" }
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

        it 'short deploy does not fail' do
          expect { deploy.short }.to_not raise_error
        end

        it 'should reconfigure the task definition' do
          deploy.deploy_config.task_definition_config = task_definition_config
          deploy.short

          register_requests = api_request_log.select { |cmd| cmd.keys.first == :register_task_definition }
          expect(register_requests.size).to eq(1)

          expect(register_requests.first.values.first[:container_definitions].first[:cpu]).to eq(cpu)
          expect(register_requests.first.values.first[:container_definitions].first[:memory]).to eq(memory)
        end

        it 'should reconfigure the service definition' do
          deploy.deploy_config.service_config = service_config
          deploy.short

          service_requests = api_request_log.select { |cmd| cmd.keys.first == :update_service }
          expect(service_requests.first.values.first[:desired_count]).to eq(desired_count)
        end

        it 'can rollback' do
          expect { deploy.rollback(1) }.to_not raise_error
          expect(api_request_log.map(&:keys).flatten).to eq([
            :list_task_definitions,
            :deregister_task_definition,
            :list_task_definitions,
            :update_service,
            :describe_services
          ])
        end
      end
    end
  end
end
