module Broadside
  class EcsConfiguration
    include ActiveModel::Model

    validates :poll_frequency, :region, presence: true, strict: ConfigurationError
    validates_each(:credentials) do |record, attr, val|
      raise ConfigurationError, 'credentials is not an Aws::Credentials' unless val.is_a?(Aws::Credentials)
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
