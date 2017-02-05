module AwsStubHelper
  def build_stub_aws_client(klass, api_request_log = [])
    client = klass.new(
      region: Broadside.config.ecs.region,
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
