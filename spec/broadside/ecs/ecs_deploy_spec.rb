require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'deploy configuration'
  include_context 'ecs stubs'

  let(:target) { Broadside::Target.new(test_target_name, test_target_config) }
  let(:deploy) { described_class.new(target: test_target_name, tag: 'tag_the_bag') }
  let(:family) { deploy.family }
  let(:desired_count) { 4 }
  let(:cpu) { 1 }
  let(:memory) { 2000 }
  let(:service_config) do
    {
      desired_count: desired_count,
      deployment_configuration: {
        minimum_healthy_percent: 40,
      }
    }
  end

  describe '#bootstrap' do
    it 'fails without task_definition_config' do
      expect { deploy.bootstrap }.to raise_error(Broadside::ConfigurationError, /No :task_definition_config/)
    end

    context 'with an existing task definition' do
      include_context 'with a task_definition'

      it 'fails without service_config' do
        expect { deploy.bootstrap }.to raise_error(/No :service_config/)
      end

      context 'with a service_config' do
        let(:local_target_config) { { service_config: service_config } }

        it 'sets up the service' do
          expect(Broadside::EcsManager).to receive(:create_service).with(cluster, deploy.family, service_config)
          expect { deploy.bootstrap }.to_not raise_error
        end

        context 'with a load_balancer_config' do
          let(:elb_config) { { subnets: [ 'subnet-xyz', 'subnet-abc'] } }
          let(:local_target_config) { { service_config: service_config, load_balancer_config: elb_config } }
          let(:load_balancer_response) do
            {
              load_balancers: [
                {
                  availability_zones: [{ subnet_id: "notorious-subnet", zone_name: 'zone' }],
                  canonical_hosted_zone_id: "ZEXAMPLE",
                  created_time: Time.now,
                  dns_name: 'dns',
                  load_balancer_arn: "arn:aws:elasticloadbalancing:arnslength",
                  load_balancer_name: family,
                  scheme: "internal",
                  security_groups: [ 'security' ],
                  state: { code: "provisioning" },
                  type: "application",
                  vpc_id: "vpc",
                }
              ]
            }
          end

          let(:service_config_args) do
            service_config.merge(
              cluster: cluster,
              load_balancers: [{ load_balancer_name: family }],
              service_name: family,
              task_definition: family
            )
          end

          it 'sets up the ELB' do
            elb_stub.stub_responses(:create_load_balancer, load_balancer_response)
            expect(elb_stub).to receive(:create_load_balancer).with(
              elb_config.merge(name: family, tags: [{ key: 'family', value: family }])
            ).and_call_original

            expect(ecs_stub).to receive(:create_service).with(service_config_args).and_call_original
            #expect(Broadside::EcsManager).to receive(:create_service).with(cluster, deploy.family, service_config)

            expect { deploy.bootstrap}.to_not raise_error
          end
        end
      end

      context 'with an existing service' do
        include_context 'with a running service'

        it 'succeeds' do
          expect { deploy.bootstrap }.to_not raise_error
        end

        context 'and some configured bootstrap commands' do
          let(:commands) { [%w(foo bar baz)] }
          let(:local_target_config) { { bootstrap_commands: commands } }

          it 'runs bootstrap commands' do
            expect(deploy).to receive(:run_commands).with(commands, started_by: 'bootstrap')
            deploy.bootstrap
          end
        end
      end
    end
  end

  describe '#deploy' do
    it 'fails without an existing service' do
      expect { deploy.short }.to raise_error(/No service for '#{deploy.family}'!/)
    end

    context 'with an existing service' do
      include_context 'with a running service'

      it 'fails without an existing task_definition' do
        expect { deploy.short }.to raise_error(/No task definition for/)
      end

      context 'with an existing task definition' do
        include_context 'with a task_definition'

        it 'short deploy does not fail' do
          expect { deploy.short }.to_not raise_error
        end

        context 'updating service and task definitions' do
          let(:task_definition_config) do
            {
              container_definitions: [
                {
                  cpu: cpu,
                  memory: memory
                }
              ]
            }
          end
          let(:local_target_config) do
            {
              task_definition_config: task_definition_config,
              service_config: service_config
            }
          end

          it 'should reconfigure the task definition' do
            deploy.short

            register_requests = api_request_log.select { |cmd| cmd.keys.first == :register_task_definition }
            expect(register_requests.size).to eq(1)
            expect(register_requests.first.values.first[:container_definitions].first[:cpu]).to eq(cpu)
            expect(register_requests.first.values.first[:container_definitions].first[:memory]).to eq(memory)
          end

          it 'should reconfigure the service definition' do
            deploy.short

            service_requests = api_request_log.select { |cmd| cmd.keys.first == :update_service }
            expect(service_requests.first.values.first[:desired_count]).to eq(desired_count)
          end

          context 'full deploy' do
            let(:predeploy_commands) { [%w(x y z), %w(a b c)] }
            let(:local_target_config) { { predeploy_commands: predeploy_commands } }

            it 'should run predeploy_commands' do
              expect(deploy).to receive(:run_commands).with(predeploy_commands, started_by: 'predeploy')
              deploy.full
            end
          end
        end

        context 'rolling back a failed deploy' do
          before do
            Broadside.config.logger.level = Logger::FATAL
          end

          it 'rolls back to the same scale' do
            expect(deploy).to receive(:update_service).once.with(no_args).and_raise('fail')
            expect(deploy).to receive(:update_service).once.with(scale: deployed_scale)
            expect { deploy.short }.to raise_error(/fail/)
          end
        end

        it 'can rollback' do
          deploy.rollback
          expect(api_request_methods.include?(:deregister_task_definition)).to be true
          expect(api_request_methods.include?(:update_service)).to be true
        end
      end
    end
  end

  describe '#run_commands' do
    let(:commands) { [%w(run some command)] }

    it 'fails without a task definition' do
      expect { deploy.run_commands(commands) }.to raise_error(Broadside::Error, /No task definition for/)
    end

    context 'with a task_definition' do
      include_context 'with a task_definition'

      let(:exit_code) { 0 }
      let(:reason) { nil }
      let(:task_exit_status) do
        {
          exit_code: exit_code,
          reason: reason
        }
      end

      before(:each) do
        ecs_stub.stub_responses(:run_task, tasks: [task_arn: 'task_arn'])
        ecs_stub.stub_responses(:wait_until, true)
        allow(Broadside::EcsManager).to receive(:get_task_exit_status).and_return(task_exit_status)
      end

      it 'runs' do
        expect(ecs_stub).to receive(:wait_until)
        expect(deploy).to receive(:get_container_logs)
        expect { deploy.run_commands(commands) }.to_not raise_error
      end

      context 'tries to start a task that does not produce an exit code' do
        let(:exit_code) { nil }
        let(:reason) { 'CannotPullContainerError: Tag BLARGH not found in repository lumoslabs/my_project' }

        it 'raises an error displaying the failure reason' do
          expect(ecs_stub).to receive(:wait_until)
          expect { deploy.run_commands(commands) }.to raise_error(Broadside::EcsError, /#{reason}/)
        end
      end

      context 'starts a task that produces a non-zero exit code' do
        let(:exit_code) { 9000 }

        it 'raises an error and displays the exit code' do
          expect(ecs_stub).to receive(:wait_until)
          expect { deploy.run_commands(commands) }.to raise_error(Broadside::EcsError, /#{exit_code}/)
        end
      end
    end
  end
end
