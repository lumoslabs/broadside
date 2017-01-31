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

    validates_each :bootstrap_commands, :predeploy_commands do |record, attr, val|
      unless val.nil? || (val.is_a?(Array) && val.all? { |v| v.is_a?(Array) })
        record.errors.add(attr, 'must be an array of arrays')
      end
    end

    validates_each :service_config, :task_definition_config do |record, attr, val|
      record.errors.add(attr, 'must be a hash') unless val.nil? || val.is_a?(Hash)
    end

    validates_each :env_files do |record, attr, v|
      unless v.nil? || v.is_a?(String) || (v.is_a?(Array) && v.all? { |file| file.is_a?(String) })
        record.errors.add(attr, 'must be a string or array of strings')
      end
    end

    validates_each :command do |record, attr, v|
      record.errors.add(attr, 'must be a string or array of strings') unless v.nil? || v.is_a?(Array)
    end

    validates :scale, numericality: true

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

      raise ArgumentError, errors.full_messages unless valid?
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
  end
end
