module Broadside
  module InvalidConfiguration
    def method_missing(m, *args, &block)
      raise ArgumentError, "Unknown configuration '#{m}' provided for #{self.class}!"
    end
  end
end
