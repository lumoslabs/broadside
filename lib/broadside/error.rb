module Broadside
  class MissingVariableError < StandardError; end

  class Error < StandardError
    def initialize(msg = 'Broadside encountered an error !')
      super
    end
  end
end
