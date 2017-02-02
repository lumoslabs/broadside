require 'broadside'
require 'pry-byebug'
Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

RSpec.configure do |config|
  config.before do
    Broadside.reset!
  end

  config.include AwsStubHelper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
