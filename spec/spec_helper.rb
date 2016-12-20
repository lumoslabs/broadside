require 'broadside'
require 'fakefs/spec_helpers'
require 'pry-byebug'

RSpec.configure do |config|
  config.before do
    Broadside.reset!
  end

  config.include FakeFS::SpecHelpers, fakefs: true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

require File.join(FIXTURES_PATH, 'configuration_examples')
