require 'spec_helper'

describe Broadside::Configuration do
  include_context 'deploy configuration'

  it 'should be able to find a target' do
    expect { Broadside.config.get_target_by_name!(test_target_name) }.to_not raise_error
  end

  it 'should raise an error when a target is missing' do
    expect { Broadside.config.get_target_by_name!('barf') }.to raise_error(ArgumentError)
  end
end
