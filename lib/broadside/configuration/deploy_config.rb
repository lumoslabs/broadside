require 'dotenv'
require 'pathname'

module Broadside
  class Configuration
    class DeployConfig < ConfigStruct
      include Utils

      # TODO this shouldn't be the default; lots of apps using broadside are not rails
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
        :predeploy_commands,
        :service_config,
        :task_definition_config
      )

      TARGET_ATTRIBUTE_VALIDATIONS = {
        scale: ->(target_attribute) { validate_types([Fixnum], target_attribute) },
        env_file: ->(target_attribute) { validate_types([String], target_attribute) },
        command: ->(target_attribute) { validate_types([Array, NilClass], target_attribute) },
        predeploy_commands: ->(target_attribute) { validate_predeploy(target_attribute) },
        service_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) },
        task_definition_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) }
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
        @service_config = nil
        @task_definition_config = nil
      end

      # Validates format of deploy targets
      # Checks existence of provided target
      def validate_targets!
        @targets.each do |target, configuration|
          invalid_messages = TARGET_ATTRIBUTE_VALIDATIONS.map do |var, validation|
            message = validation.call(configuration[var])
            message.nil? ? nil : "Deploy target '#{@target}' parameter '#{var}' is invalid: #{message}"
          end.compact

          unless invalid_messages.empty?
            raise ArgumentError, invalid_messages.join("\n")
          end
        end

        unless @targets.has_key?(@target)
          raise ArgumentError, "Could not find deploy target #{@target} in configuration !"
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
          raise ArgumentError, "Could not find file '#{env_file}' for loading environment variables !"
        end

        @scale ||= @targets[@target][:scale]
        @command = @targets[@target][:command]
        @predeploy_commands = @targets[@target][:predeploy_commands] if @targets[@target][:predeploy_commands]
        @service_config = @targets[@target][:service_config]
        @task_definition_config = @targets[@target][:task_definition_config]
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

        messages = target_attribute.select { |cmd| !cmd.is_a?(Array) }.map do |command|
          "predeploy_command '#{command}' must be an array" unless command.is_a?(Array)
        end
        messages.empty? ? nil : messages.join(', ')
      end
    end
  end
end
