module Broadside
  class EcsError < StandardError; end
  class MissingVariableError < StandardError; end

  class Error < StandardError
    def initialize(msg = 'Broadside encountered an error !')
      super
    end
  end
end
