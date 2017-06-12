module Broadside
  class AwsConfiguration
    include ActiveModel::Model
    include InvalidConfiguration

    validates :region, presence: true, strict: ConfigurationError
    validates :ecs_poll_frequency, numericality: { only_integer: true, strict: ConfigurationError }
    validates_each(:credentials) do |_, _, val|
      raise ConfigurationError, 'credentials is not of type Aws::Credentials' unless val.is_a?(Aws::Credentials)
    end

    attr_accessor(
      :credentials,
      :ecs_default_cluster,
      :ecs_poll_frequency,
      :region
    )

    def initialize
      @credentials = Aws::SharedCredentials.new.credentials

      # Try instance profile credentials if shared credentials don't exist
      if @credentials.nil?
        @credentials = Aws::InstanceProfileCredentials.new.credentials
      end

      @ecs_poll_frequency = 2
      @region = 'us-east-1'
    end
  end
end
