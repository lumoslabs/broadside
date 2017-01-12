require 'dotenv'
require 'pathname'

module Broadside
  class Command
    include ConfigStruct

    attr_accessor(
      :tag,
      :rollback,
      :timeout,
      :targets,
      :instance,
      :lines
    )

    def initialize
      @tag = nil
      @scale = nil
      @env_vars = nil
      @command = nil
      @predeploy_commands = DEFAULT_PREDEPLOY_COMMANDS
      @instance = 0
      @lines = 10
    end
  end
end