require 'spec_helper'

describe Broadside::Command do
  include_context 'deploy configuration'
  include_context 'ecs stubs'

  let(:tag) { 'tag_tag' }
  let(:context_deploy_config) { {} }
  let(:deploy_config) { { target: test_target_name }.merge(context_deploy_config) }
  let(:deploy) { Broadside::EcsDeploy.new(deploy_config[:target], deploy_config) }
  let(:family) { Broadside.config.get_target_by_name!(deploy_config[:target]).family }

  before do
    expect(Broadside::EcsDeploy).to receive(:new).and_return(deploy)
  end

  describe '#run' do
    let(:context_deploy_config) { run_options }
    let(:run_options) { { tag: tag } }

    it 'fails without a task definition' do
      expect { described_class.run(run_options) }.to raise_error(/No task definition/)
    end

    context 'with a task_definition' do
      include_context 'with a task_definition'

      let(:command) { %w(run some command) }
      let(:command_options) { run_options.merge(command: command) }

      before do
        ecs_stub.stub_responses(:run_task, tasks: [task_arn: 'task_arn'])
      end

      it 'runs' do
        expect(ecs_stub).to receive(:wait_until)
        expect(Broadside::EcsManager).to receive(:get_running_instance_ips).and_return(['123.123.123.123'])
        expect(deploy).to receive(:`).and_return('')
        expect(Broadside::EcsManager).to receive(:get_task_exit_code).and_return(0)
        expect { described_class.run(command_options) }.to_not raise_error
      end
    end
  end

  describe '#bash' do
    it 'fails without a running service' do
      expect { described_class.bash(deploy_config) }.to raise_error(Broadside::Error, /No task definition/)
    end

    context 'with a task definition and service in place' do
      include_context 'with a running service'
      include_context 'with a task_definition'

      it 'fails without a running task' do
        expect { described_class.bash(deploy_config) }.to raise_error /No running tasks found for/
      end

      context 'with a running task' do
        let(:task_arn) { 'some_task_arn' }
        let(:container_arn) { 'some_container_arn' }
        let(:instance_id) { 'i-xxxxxxxx' }
        let(:ip) { '123.123.123.123' }

        before(:each) do
          ecs_stub.stub_responses(:list_tasks, task_arns: [task_arn])
          ecs_stub.stub_responses(:describe_tasks, tasks: [{ container_instance_arn: container_arn }])
          ecs_stub.stub_responses(:describe_container_instances, container_instances: [{ ec2_instance_id: instance_id }])
          ec2_stub.stub_responses(:describe_instances, reservations: [ instances: [{ private_ip_address: ip }]])
        end

        it 'executes correct system command' do
          expect(described_class).to receive(:exec).with("ssh -o StrictHostKeyChecking=no -t -t #{user}@#{ip} 'docker exec -i -t `docker ps -n 1 --quiet --filter name=#{family}` bash'")
          expect { described_class.bash(deploy_config) }.to_not raise_error
          expect(api_request_log).to eq(
            [
              { list_task_definitions: { family_prefix: family } },
              { describe_services: { cluster: cluster, services: [family] } },
              { list_tasks: { cluster: cluster, family: family } },
              { describe_tasks: { cluster: cluster, tasks: [task_arn] } },
              { describe_container_instances: { cluster: cluster, container_instances: [container_arn] } },
              { describe_instances: { instance_ids: [instance_id] } }
            ]
          )
        end
      end
    end
  end
end
