module Broadside
  class AwsConfig
    include VerifyInstanceVariables

    attr_accessor :region, :credentials

    def initialize
      @region = 'us-east-1'
      @credentials = Aws::SharedCredentials.new.credentials
    end
  end
end
