module Broadside
  module InvalidConfiguration
    def method_missing(m, *args, &block)
      message = "Unknown '#{m}' provided for #{self.is_a?(AwsConfiguration) ? 'configuration.aws' : 'configuration'}!"
      raise ArgumentError, message
    end
  end
end
