require 'dotenv'
require 'pathname'

module Broadside
  class Target
    include VerifyInstanceVariables
    include Utils

    attr_accessor(
      :bootstrap_commands,
      :env_files,
      :env_vars,
      :instance,
      :name,
      :predeploy_commands,
      :scale,
      :service_config,
      :tag,
      :task_definition_config
    )

    DEFAULT_INSTANCE = 0

    TARGET_ATTRIBUTE_VALIDATIONS = {
      bootstrap_commands:     ->(target_attribute) { validate_commands(target_attribute) },
      env_files:              ->(target_attribute) { validate_types([String, Array], target_attribute) },
      predeploy_commands:     ->(target_attribute) { validate_commands(target_attribute) },
      scale:                  ->(target_attribute) { validate_types([Integer], target_attribute) },
      service_config:         ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) },
      task_definition_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) }
    }

    def initialize(name, options = {})
      @name = name
      @config = options

      @bootstrap_commands = @config[:bootstrap_commands] || []
      @cluster = @config[:cluster]
      _env_files = @config[:env_files] || @config[:env_file]
      @env_files = _env_files ? [*_env_files] : nil
      @env_vars = {}
      @instance = DEFAULT_INSTANCE || @config[:instance]
      @predeploy_commands = @config[:predeploy_commands]
      @scale = @config[:scale]
      @service_config = @config[:service_config]
      @tag = @config[:tag]
      @task_definition_config = @config[:task_definition_config]

      validate!
      load_env_vars!
    end

    def cluster
      @cluster || config.ecs.cluster
    end

    private

    def validate!
      invalid_messages = TARGET_ATTRIBUTE_VALIDATIONS.map do |var, validation|
        message = validation.call(instance_variable_get('@' + var.to_s))
        message.nil? ? nil : "Deploy target '#{@name}' parameter '#{var}' is invalid: #{message}"
      end.compact

      unless invalid_messages.empty?
        raise ArgumentError, invalid_messages.join("\n")
      end
    end

    def load_env_vars!
      @env_files.flatten.each do |env_path|
        env_file = Pathname.new(env_path)

        unless env_file.absolute?
          dir = config.file.nil? ? Dir.pwd : Pathname.new(config.file).dirname
          env_file = env_file.expand_path(dir)
        end

        if env_file.exist?
          vars = Dotenv.load(env_file)
          @env_vars.merge!(vars)
        else
          raise ArgumentError, "Could not find file '#{env_file}' for loading environment variables !"
        end
      end

      # convert env vars to format ecs expects
      @env_vars = @env_vars.map { |k, v| { 'name' => k, 'value' => v } }
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
