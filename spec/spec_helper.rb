require 'broadside'
require 'fakefs/spec_helpers'
require 'pry-byebug'

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
require File.join(FIXTURES_PATH, 'configuration_context')

module AwsStubHelper
  def build_stub_aws_client(klass, api_request_log = [])
    client = klass.new(
      region: Broadside.config.aws.region,
      credentials: Aws::Credentials.new('access', 'secret'),
      stub_responses: true
    )

    client.handle do |context|
      api_request_log << { context.operation_name => context.params }
      @handler.call(context)
    end

    client
  end
end

RSpec.configure do |config|
  config.before do
    Broadside.reset!
  end

  config.include FakeFS::SpecHelpers, fakefs: true
  config.include AwsStubHelper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
