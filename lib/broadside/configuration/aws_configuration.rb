module Broadside
  class AwsConfiguration
    include ActiveModel::Model
    include InvalidConfiguration

    validates :debug, presence: true
    validates :region, presence: true, strict: ConfigurationError
    validates :ecs_poll_frequency, numericality: { only_integer: true, strict: ConfigurationError }
    validates_each(:credentials) do |_, _, val|
      raise ConfigurationError, 'credentials is not of type Aws::Credentials' unless val.is_a?(Aws::Credentials)
    end

    attr_writer :credentials
    attr_accessor(
      :ecs_default_cluster,
      :ecs_poll_frequency,
      :region,
      :debug
    )

    def initialize
      @ecs_poll_frequency = 2
      @region = 'us-east-1'
      @debug = false
    end

    def credentials
      @credentials ||= Aws::SharedCredentials.new.credentials || Aws::InstanceProfileCredentials.new.credentials
    end
  end
end
