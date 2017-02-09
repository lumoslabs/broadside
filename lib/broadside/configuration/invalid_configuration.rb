module Broadside
  module InvalidConfiguration
    extend LoggingUtils

    def method_missing(m, *args, &block)
      warn "Unknown configuration '#{m}' provided, ignoring."
    end

    def respond_to_missing?(method, include_private = false)
      super
    end
  end
end
