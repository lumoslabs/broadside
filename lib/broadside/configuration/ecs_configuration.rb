module Broadside
  class EcsConfiguration
    attr_accessor(
      :credentials,
      :default_cluster,
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
