require 'spec_helper'

describe Broadside::Command do
  include_context 'deploy configuration'
  include_context 'ecs stubs'

  describe '#run' do
    let(:family) { Broadside.config.get_target_by_name!(test_target_name).family }
    let(:tag) { 'tag_tag' }
    let(:run_options) { { target: test_target_name, tag: tag } }

    it 'fails without a task definition' do
      expect { described_class.run(run_options) }.to raise_error(/No task definition/)
    end

    context 'with a task_definition' do
      include_context 'with a task_definition'

      let(:command) { %w(run some command) }
      let(:deploy) { Broadside::EcsDeploy.new(test_target_name, tag: tag) }
      let(:command_options) { run_options.merge(command: command) }

      before do
        ecs_stub.stub_responses(:run_task, tasks: [task_arn: 'task_arn'])
      end

      it 'runs' do
        expect(Broadside::EcsDeploy).to receive(:new).with(test_target_name, command_options).and_return(deploy)
        expect(ecs_stub).to receive(:wait_until)
        expect(Broadside::EcsManager).to receive(:get_running_instance_ips).and_return(['123.123.123.123'])
        expect(deploy).to receive(:`).and_return('')
        expect(Broadside::EcsManager).to receive(:get_task_exit_code).and_return(0)
        expect { described_class.run(command_options) }.to_not raise_error
      end
    end
  end
end
