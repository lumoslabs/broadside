module Broadside
  class ConfigurationError < ArgumentError; end
  class EcsError < StandardError; end

  class Error < StandardError
    def initialize(msg = 'Broadside encountered an error !')
      super
    end
  end
end
