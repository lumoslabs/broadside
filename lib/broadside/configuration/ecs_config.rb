module Broadside
  class EcsConfig
    attr_accessor(
      :cluster,
      :credentials,
      :poll_frequency,
      :region
    )

    def initialize
      @credentials = Aws::SharedCredentials.new.credentials
      @poll_frequency = 2
      @region = 'us-east-1'
    end
  end
end
