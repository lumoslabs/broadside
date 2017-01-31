require 'active_support/core_ext/array'
require 'dotenv'
require 'pathname'

module Broadside
  class Target
    include VerifyInstanceVariables
    include LoggingUtils

    attr_reader(
      :bootstrap_commands,
      :command,
      :env_files,
      :env_vars,
      :name,
      :predeploy_commands,
      :scale,
      :service_config,
      :task_definition_config
    )

    def initialize(name, options = {})
      @name = name
      @config = options

      @bootstrap_commands = @config[:bootstrap_commands]
      @cluster = @config[:cluster]
      @command = @config[:command]
      @env_files = Array.wrap(@config[:env_files] || @config[:env_file])
      @env_vars = {}
      @predeploy_commands = @config[:predeploy_commands]
      @scale = @config[:scale]
      @service_config = @config[:service_config]
      @task_definition_config = @config[:task_definition_config]

      validate!
    end

    def load_env_vars!
      @env_files.flatten.each do |env_path|
        env_file = Pathname.new(env_path)

        unless env_file.absolute?
          dir = config.config_file.nil? ? Dir.pwd : Pathname.new(config.config_file).dirname
          env_file = env_file.expand_path(dir)
        end

        raise ArgumentError, "Could not find env_file '#{env_file}'!" unless env_file.exist?

        begin
          @env_vars.merge!(Dotenv.load(env_file))
        rescue Dotenv::FormatError => e
          raise e.class, "Dotenv gem error: '#{e.message}' while parsing #{env_file}", e.backtrace
        end
      end

      # convert env vars to format ecs expects
      @env_vars = @env_vars.map { |k, v| { 'name' => k, 'value' => v } }
    end

    def cluster
      @cluster || Broadside.config.ecs.cluster
    end

    private

    TARGET_ATTRIBUTE_VALIDATIONS = {
      bootstrap_commands:     ->(target_attribute) { validate_commands(target_attribute) },
      command:                ->(target_attribute) { validate_types([Array, NilClass], target_attribute) },
      env_files:              ->(target_attribute) { validate_types([String, Array, NilClass], target_attribute) },
      predeploy_commands:     ->(target_attribute) { validate_commands(target_attribute) },
      scale:                  ->(target_attribute) { validate_types([Integer], target_attribute) },
      service_config:         ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) },
      task_definition_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) }
    }.freeze

    def validate!
      invalid_messages = TARGET_ATTRIBUTE_VALIDATIONS.map do |var, validation|
        message = validation.call(instance_variable_get('@' + var.to_s))
        message.nil? ? nil : "Deploy target '#{@name}' parameter '#{var}' is invalid: #{message}"
      end.compact

      unless invalid_messages.empty?
        raise ArgumentError, invalid_messages.join("\n")
      end
    end

    def self.validate_types(types, target_attribute)
      return nil if types.any? { |type| target_attribute.is_a?(type) }
      "'#{target_attribute}' must be of type [#{types.join('|')}], got '#{target_attribute.class}' !"
    end

    def self.validate_commands(commands)
      return nil if commands.nil?
      return 'predeploy_commands must be an array' unless commands.is_a?(Array)

      messages = commands.reject { |cmd| cmd.is_a?(Array) }.map do |command|
        "predeploy_command '#{command}' must be an array" unless command.is_a?(Array)
      end
      messages.empty? ? nil : messages.join(', ')
    end
  end
end
