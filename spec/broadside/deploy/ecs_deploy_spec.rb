require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'deploy configuration'

  let(:family) { "#{test_app}_#{test_target}" }
  let(:target) { Broadside::Target.new(test_target, test_target_config) }
  let(:deploy) { described_class.new(target, tag: 'tag_the_bag') }
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

  let(:arn) { 'arn:aws:ecs:us-east-1:1234' }
  let(:existing_service) do
    {
      service_name: test_target.to_s,
      service_arn: "#{arn}:service/#{test_target}",
      deployments: [{ desired_count: 1, running_count: 1 }]
    }
  end
  let(:stub_service_response) { { services: [existing_service], failures: [] } }
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

  before(:each) { Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end

  context 'bootstrap' do
    it 'fails without task_definition_config' do
      expect { deploy.bootstrap }.to raise_error(//)
    end

    context 'with an existing task definition' do
      before(:each) do
        ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_response)
        ecs_stub.stub_responses(:describe_task_definition, stub_describe_task_definition_response)
      end

      it 'fails without service_config' do
        deploy.target.task_definition_config = task_definition_config

        expect { deploy.bootstrap }.to raise_error(/Service doesn't exist and no :service_config/)
      end

      context 'with an existing service' do
        before(:each) do
          ecs_stub.stub_responses(:describe_services, stub_service_response)
        end

        it 'succeeds' do
          deploy.target.service_config = service_config
          deploy.target.task_definition_config = task_definition_config

          expect { deploy.bootstrap }.to_not raise_error
        end

        context 'and some configured bootstrap commands' do
          let(:commands) { [%w(foo bar baz)] }
          let(:target) do
            Broadside::Target.new(test_target, test_target_config.merge(bootstrap_commands: commands))
          end

          it 'runs bootstrap commands' do
            expect(deploy).to receive(:run_commands).with(commands)
            deploy.bootstrap
          end
        end
      end
    end
  end

  context 'deploy' do
    it 'fails without an existing service' do
      expect { deploy.deploy }.to raise_error(/No service for '#{family}'!/)
    end

    context 'with an existing service' do
      before(:each) do
        ecs_stub.stub_responses(:describe_services, stub_service_response)
      end

      it 'fails without an existing task_definition' do
        expect { deploy.deploy }.to raise_error(/No task definition for/)
      end

      context 'with an existing task definition' do
        before(:each) do
          ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_response)
          ecs_stub.stub_responses(:describe_task_definition, stub_describe_task_definition_response)
        end

        it 'short deploy does not fail' do
          expect { deploy.short }.to_not raise_error
        end

        it 'should reconfigure the task definition' do
          deploy.target.task_definition_config = task_definition_config
          deploy.short

          register_requests = api_request_log.select { |cmd| cmd.keys.first == :register_task_definition }
          expect(register_requests.size).to eq(1)

          expect(register_requests.first.values.first[:container_definitions].first[:cpu]).to eq(cpu)
          expect(register_requests.first.values.first[:container_definitions].first[:memory]).to eq(memory)
        end

        it 'should reconfigure the service definition' do
          deploy.target.service_config = service_config
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

  context 'bash' do
    it 'fails without a running task' do
      expect { deploy.bash }.to raise_error(Broadside::Error, /No running tasks found/)
    end

    context 'with a running task' do
      let(:task_arn) { 'some_task_arn'}
      let(:container_arn) { 'some_container_arn' }
      let(:instance_id) { 'i-xxxxxxxx' }
      let(:ip) { '123.123.123.123' }
      let(:ec2_stub) do
        requests = api_request_log
        client = Aws::EC2::Client.new(
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

      before(:each) do
        Broadside::EcsManager.instance_variable_set(:@ec2_client, ec2_stub)
        ecs_stub.stub_responses(:list_tasks, task_arns: [task_arn])
        ecs_stub.stub_responses(:describe_tasks, tasks: [container_instance_arn: container_arn])
        ecs_stub.stub_responses(:describe_container_instances, container_instances: [{ ec2_instance_id: instance_id }])
        ec2_stub.stub_responses(:describe_instances, { reservations: [ instances: [ { private_ip_address: ip } ] ] })

        allow(deploy).to receive(:exec).with("ssh -o StrictHostKeyChecking=no -t -t #{user}@#{ip} 'docker exec -i -t `docker ps -n 1 --quiet --filter name=#{family}` bash'").and_return(true)
      end

      it 'executes correct system command' do
        expect { deploy.bash }.to_not raise_error
        expect(api_request_log).to eq([
          { list_tasks: { cluster: cluster, family: family } },
          { describe_tasks: { cluster: cluster, tasks: [task_arn] } },
          { describe_container_instances: { cluster: cluster, container_instances: [container_arn] } },
          { describe_instances: { instance_ids: [instance_id] } }
        ])
      end
    end
  end
end
