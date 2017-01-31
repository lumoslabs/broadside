require 'active_model'
require 'active_support/core_ext/array'
require 'dotenv'
require 'pathname'

module Broadside
  class Target
    include ActiveModel::Model
    include LoggingUtils
    include VerifyInstanceVariables

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

    validates :cluster, :name, presence: true
    validates :scale, numericality: { only_integer: true }

    validates_each :bootstrap_commands, :predeploy_commands, allow_nil: true do |record, attr, val|
      record.errors.add(attr, 'must be an array of arrays') unless val.is_a?(Array) && val.all? { |v| v.is_a?(Array) }
    end

    validates_each :service_config, :task_definition_config, allow_nil: true do |record, attr, val|
      record.errors.add(attr, 'must be a hash') unless val.is_a?(Hash)
    end

    validates_each :command, allow_nil: true do |record, attr, val|
      record.errors.add(attr, 'must be an array') unless val.is_a?(Array)
    end

    def initialize(name, options = {})
      @name = name
      @config = options

      @bootstrap_commands = @config[:bootstrap_commands]
      @cluster = @config[:cluster]
      @command = @config[:command]
      @env_files = Array.wrap(@config[:env_files] || @config[:env_file]).map do |env_path|
        env_file = Pathname.new(env_path)
        next env_file if env_file.absolute?

        dir = Broadside.config.config_file ? Pathname.new(Broadside.config.config_file).dirname : Dir.pwd
        env_file.expand_path(dir)
      end
      @predeploy_commands = @config[:predeploy_commands]
      @scale = @config[:scale]
      @service_config = @config[:service_config]
      @task_definition_config = @config[:task_definition_config]

      raise ArgumentError, errors.full_messages unless valid?
    end

    # Convert env files to key/value format ECS expects
    def load_env_vars!
      @env_vars = @env_files.inject({}) do |memo, env_file|
        raise "#{env_file} does not exist!" unless env_file.exist?

        begin
          memo.merge(Dotenv.load(env_file))
        rescue Dotenv::FormatError => e
          raise e.class, "Error parsing #{env_file}: #{e.message}", e.backtrace
        end
      end.map { |k, v| { 'name' => k, 'value' => v } }
    end

    def cluster
      @cluster || Broadside.config.ecs.cluster
    end
  end
end
