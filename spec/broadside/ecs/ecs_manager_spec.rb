require 'spec_helper'

# Hitting the stubbed Aws::ECS::Client serves to validate the request format we are sending

describe Broadside::EcsManager do
  include_context 'ecs stubs'

  let(:service_name) { 'service' }
  let(:cluster) { 'cluster' }
  let(:name) { 'job' }

  describe '#create_service' do
    it 'creates an ECS service from the given configs' do
      expect { described_class.create_service(cluster, service_name) }.to_not raise_error
    end
  end

  describe '#list_services' do
    it 'returns an array of services belonging to the provided cluster' do
      expect { described_class.list_services(cluster) }.to_not raise_error
    end
  end

  describe '#get_task_arns' do
    it 'returns an array of task arns belonging to a provided cluster with the provided name' do
      expect { described_class.get_task_arns(cluster, name) }.to_not raise_error
    end
  end

  describe '#get_task_definition_arns' do
    it 'returns an array of task definition arns with the provided name' do
      expect { described_class.get_task_definition_arns(name) }.to_not raise_error
      expect { described_class.get_latest_task_definition_arn(name) }.to_not raise_error
    end
  end

  describe '#get_latest_task_definition' do
    it 'returns the most recent valid task definition' do
      expect(described_class.get_latest_task_definition(name)).to be_nil
    end
  end

  describe '#all_results' do
    let(:task_definition_arns) { ['arn:task-definition/task:1', 'arn:task-definition/other_task:1'] }
    let(:stub_task_definition_responses) do
      [
        { task_definition_arns: [task_definition_arns[0]], next_token: 'MzQ3N' },
        { task_definition_arns: [task_definition_arns[1]] }
      ]
    end

    before do
      ecs_stub.stub_responses(:list_task_definitions, stub_task_definition_responses)
    end

    it 'can pull multipage results' do
      expect(described_class.get_task_definition_arns('task')).to eq(task_definition_arns)
    end
  end

  context 'load balancers' do
    let(:elb_name) { 'my-load-balancer' }
    let(:elb_config) { { name: elb_name,  subnets: ['subnet-xyz', 'subnet-abc'] } }
    let(:elb_arn) { 'elb_arn' }
    let(:elb_response) { { load_balancer_arn: elb_arn, load_balancer_name: elb_config[:name] } }

    it 'can create an ELB' do
      described_class.create_load_balancer(elb_config)
    end

    describe '#get_load_balancer_arn_by_name' do
      before do
        elb_stub.stub_responses(:describe_load_balancers, load_balancers: [elb_response])
      end

      it 'should find the relevant elb config' do
        expect(described_class.get_load_balancer_arn_by_name(elb_name)).to eq(elb_arn)
      end
    end
  end
end
