require 'aws-sdk'

module Broadside
  class Configuration
    class AwsConfig < ConfigStruct
      attr_accessor :region, :credentials

      def initialize
        @region = 'us-east-1'
        @credentials = Aws::SharedCredentials.new.credentials
      end
    end
  end
end
