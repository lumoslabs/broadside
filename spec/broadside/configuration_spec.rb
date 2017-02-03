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
end
