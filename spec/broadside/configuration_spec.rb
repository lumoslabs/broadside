require 'spec_helper'

describe Broadside::Configuration do
  include_context 'deploy configuration'

  it 'should be able to find a target' do
    expect { Broadside.config.get_target_by_name!(test_target_name) }.to_not raise_error
  end

  it 'should raise an error when a target is missing' do
    expect { Broadside.config.get_target_by_name!('barf') }.to raise_error(ArgumentError)
  end

  it 'should raise an error when missing aws variables' do
    Broadside.configure do |config|
      config.aws.region = nil
    end
    expect(Broadside.config.valid?).to be false
  end

  it 'should raise an error when ecs.poll_frequency is invalid' do
    Broadside.configure do |config|
      config.ecs.poll_frequency = 'notanumber'
    end
    expect(Broadside.config.valid?).to be false
  end

  context 'ssh' do
    let(:ip) { '123.123.123.123' }

    it 'should build the ssh command with a user' do
      expect(Broadside.config.ssh_cmd(ip)).to eq("ssh -o StrictHostKeyChecking=no #{user}@#{ip}")
    end

    it 'should build the ssh command without a user' do
      Broadside.configure do |config|
        config.ssh = {}
      end
      expect(Broadside.config.ssh_cmd(ip)).to eq("ssh -o StrictHostKeyChecking=no #{ip}")
    end
  end
end
