require 'dotenv'
require 'pathname'

module Broadside
  class Configuration
    class DeployConfig < ConfigStruct
      include Utils

      DEFAULT_PREDEPLOY_COMMANDS = [
        ['bundle', 'exec', 'rake', '--trace', 'db:migrate']
      ]

      attr_accessor(
        :type,
        :tag,
        :ssh,
        :rollback,
        :timeout,
        :target,
        :targets,
        :scale,
        :env_vars,
        :command,
        :instance,
        :predeploy_commands
      )

      TARGET_ATTRIBUTE_VALIDATIONS = {
        scale: ->(target_attribute) { validate_types([Fixnum], target_attribute) },
        env_file: ->(target_attribute) { validate_types([String], target_attribute) },
        command: ->(target_attribute) { validate_types([Array, NilClass], target_attribute) },
        predeploy_commands: ->(target_attribute) { validate_predeploy(target_attribute) }
      }

      def initialize
        @type = 'ecs'
        @ssh = nil
        @tag = nil
        @rollback = 1
        @timeout = 600
        @target = nil
        @targets = nil
        @scale = nil
        @env_vars = nil
        @command = nil
        @predeploy_commands = DEFAULT_PREDEPLOY_COMMANDS
        @instance = 0
      end

      # Validates format of deploy targets
      # Checks existence of provided target
      def validate_targets!
        @targets.each do |target, configuration|
          TARGET_ATTRIBUTE_VALIDATIONS.each do |var, validation|
            message = validation.call(configuration[var])

            unless message.nil?
              exception "Deploy target '#{@target}' parameter '#{var}' is invalid: #{message}"
            end
          end
        end

        unless @targets.has_key?(@target)
          exception "Could not find deploy target #{@target} in configuration !"
        end
      end

      # Loads deploy target data using provided target
      def load_target!
        validate_targets!

        env_file = Pathname.new(@targets[@target][:env_file])

        unless env_file.absolute?
          dir = config.file.nil? ? Dir.pwd : Pathname.new(config.file).dirname
          env_file = env_file.expand_path(dir)
        end

        if env_file.exist?
          vars = Dotenv.load(env_file)
          @env_vars = vars.map { |k,v| {'name'=> k, 'value' => v } }
        else
          exception "Could not find file '#{env_file}' for loading environment variables !"
        end

        @scale ||= @targets[@target][:scale]
        @command = @targets[@target][:command]
        @predeploy_commands = @targets[@target][:predeploy_commands] if @targets[@target][:predeploy_commands]
      end

      private

      def self.validate_types(types, target_attribute)
        unless types.include?(target_attribute.class)
          return "'#{target_attribute}' must be of type [#{types.join('|')}], got '#{target_attribute.class}' !"
        end

        nil
      end

      def self.validate_predeploy(target_attribute)
        return nil if target_attribute.nil?

        return 'predeploy_commands must be an array' unless target_attribute.is_a?(Array)

        target_attribute.each do |command|
          return "predeploy_command '#{command}' must be an array" unless command.is_a?(Array)
        end

        nil
      end
    end
  end
end
