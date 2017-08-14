require 'spec_helper'

describe Broadside::Command do
  include_context 'deploy configuration'
  include_context 'ecs stubs'

  let(:tag) { 'tag_tag' }
  let(:context_deploy_config) { {} }
  let(:deploy_config) { { target: test_target_name }.merge(context_deploy_config) }
  let(:deploy) { Broadside::EcsDeploy.new(deploy_config) }
  let(:family) { Broadside.config.get_target_by_name!(deploy_config[:target]).family }

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
        let(:docker_cmd) { "ssh -o StrictHostKeyChecking=no -t -t #{user}@#{ip} 'docker exec -i -t `docker ps -n 1 --quiet --filter name=#{family}`" }
        let(:request_log) do
          [
            { list_task_definitions: { family_prefix: family } },
            { describe_services: { cluster: cluster, services: [family] } },
            { list_tasks: { cluster: cluster, family: family } },
            { describe_tasks: { cluster: cluster, tasks: [task_arn] } },
            { describe_container_instances: { cluster: cluster, container_instances: [container_arn] } },
            { describe_instances: { instance_ids: [instance_id] } }
          ]
        end

        before(:each) do
          ecs_stub.stub_responses(:list_tasks, task_arns: [task_arn])
          ecs_stub.stub_responses(:describe_tasks, tasks: [{ container_instance_arn: container_arn }])
          ecs_stub.stub_responses(:describe_container_instances, container_instances: [{ ec2_instance_id: instance_id }])
          ec2_stub.stub_responses(:describe_instances, reservations: [{ instances: [{ private_ip_address: ip }] }])
        end

        it 'raises an exception if the requested server index does not exist' do
          expect do
            described_class.bash(deploy_config.merge(instance: 2))
          end.to raise_error(Broadside::Error, /There are only 1 instances; index 2 does not exist/)
        end

        it 'executes correct bash command' do
          expect(described_class).to receive(:exec).with("#{docker_cmd} bash'")
          expect { described_class.bash(deploy_config) }.to_not raise_error
          expect(api_request_log).to eq(request_log)
        end

        it 'executes correct bash command' do
          expect(described_class).to receive(:exec).with("#{docker_cmd} ls'")
          expect { described_class.bash(deploy_config.merge(command: 'ls')) }.to_not raise_error
          expect(api_request_log).to eq(request_log)
        end
      end
    end
  end
end
