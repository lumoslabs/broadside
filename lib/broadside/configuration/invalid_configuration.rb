module Broadside
  module InvalidConfiguration
    extend LoggingUtils

    def method_missing(m, _, &block)
      warn "Unknown configuration '#{m}' provided, ignoring..."
    end
  end
end
