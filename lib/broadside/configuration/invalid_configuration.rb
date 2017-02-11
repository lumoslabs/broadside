module Broadside
  module InvalidConfiguration
    def method_missing(m, _, &block)
      raise ConfigurationError, "Unknown configuration '#{m}' provided!"
    end
  end
end
