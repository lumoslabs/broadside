module Broadside
  class AwsConfiguration
    include ActiveModel::Model
    include InvalidConfiguration

    validates :region, presence: true, strict: ConfigurationError
    validates :poll_frequency, numericality: { only_integer: true, strict: ConfigurationError }
    validates_each(:credentials) do |_, _, val|
      raise ConfigurationError, 'credentials is not of type Aws::Credentials' unless val.is_a?(Aws::Credentials)
    end

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
