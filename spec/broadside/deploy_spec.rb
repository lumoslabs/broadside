require 'spec_helper'

module Broadside
  describe Deploy do
    let(:valid_options) do
      {
        tag: 'NEW_TEST_TAG',
        target: :TEST_TARGET,
        scale: 100,
        rollback: 100,
        instance: 100,
        cmd: ['echo', 'TEST']
      }
    end
    let(:invalid_options) do
      {
        target: nil,
      }
    end

    describe '#deploy' do
      context 'with valid deploy configuration' do
        include_context 'deploy configuration'
        let(:d) { Deploy.new(valid_options) }

        it 'verifies existence of a tag configuration' do
          expect(d.deploy_config).to receive(:verify).with(:tag)
          d.deploy {}
        end
      end
    end

    describe '#rollback' do
      context 'with valid deploy configuration' do
        include_context 'deploy configuration'
        let(:d) { Deploy.new(valid_options) }

        it 'verifies existence of rollback configuration' do
          expect(d.deploy_config).to receive(:verify).with(:rollback)
          d.rollback {}
        end
      end
    end

    describe '#run' do
      context 'with valid deploy configuration' do
        include_context 'deploy configuration'
        let(:d) { Deploy.new(valid_options) }

        it 'verifies existence of a tag, ssh, command configuration' do
          expect(d.deploy_config).to receive(:verify).with(:tag, :ssh, :command)
          d.run {}
        end
      end
    end

    describe '#run_predeploy' do
      context 'with valid deploy configuration' do
        include_context 'deploy configuration'
        let(:d) { Deploy.new(valid_options) }

        it 'verifies existence of a tag and ssh configuration' do
          expect(d.deploy_config).to receive(:verify).with(:tag, :ssh)
          d.run_predeploy {}
        end
      end
    end
  end
end
