module Broadside
  module InvalidConfiguration
    extend LoggingUtils

    def method_missing(m, *args, &block)
      warn "Unknown configuration '#{m}' provided, ignoring."
    end
  end
end
