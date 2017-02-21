module Broadside
  module InvalidConfiguration
    def method_missing(m, *args, &block)
      raise ArgumentError, 'config.' + (is_a?(AwsConfiguration) ? 'aws.' : '') + m.to_s + ' is an invalid config option'
    end
  end
end
