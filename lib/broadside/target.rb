require 'dotenv'
require 'pathname'

module Broadside
  class Target
    include ActiveModel::Model
    include LoggingUtils

    attr_reader(
      :bootstrap_commands,
      :cluster,
      :command,
      :docker_image,
      :load_balancer_config,
      :name,
      :predeploy_commands,
      :scale,
      :service_config,
      :tag,
      :task_definition_config
    )

    validates :cluster, :docker_image, :name, presence: true
    validates :scale, numericality: { only_integer: true }

    validates_each(:bootstrap_commands, :predeploy_commands, allow_nil: true) do |record, attr, val|
      record.errors.add(attr, 'is not array of arrays') unless val.is_a?(Array) && val.all? { |v| v.is_a?(Array) }
    end

    validates_each(:service_config, allow_nil: true) do |record, attr, val|
      record.errors.add(attr, 'is not a hash') unless val.is_a?(Hash)
    end

    validates_each(:load_balancer_config, allow_nil: true) do |record, attr, val|
      record.errors.add(attr, 'is not a hash') unless val.is_a?(Hash)
      record.errors.add(attr, ':load_balancer_name is set automatically') if val[:load_balancer_name]
      record.errors.add(attr, ':subnets is required') unless val[:subnets] && val[:subnets].is_a?(Array)
    end

    validates_each(:task_definition_config, allow_nil: true) do |record, attr, val|
      if val.is_a?(Hash)
        if val[:container_definitions] && val[:container_definitions].size > 1
          record.errors.add(attr, 'specifies > 1 container definition but this is not supported yet')
        end
      else
        record.errors.add(attr, 'is not a hash')
      end
    end

    validates_each(:command, allow_nil: true) do |record, attr, val|
      record.errors.add(attr, 'is not an array of strings') unless val.is_a?(Array) && val.all? { |v| v.is_a?(String) }
    end

    def initialize(name, options = {})
      @name = name

      config = options.deep_dup
      @bootstrap_commands     = config.delete(:bootstrap_commands)
      @cluster                = config.delete(:cluster) || Broadside.config.aws.ecs_default_cluster
      @command                = config.delete(:command)
      @docker_image           = config.delete(:docker_image) || Broadside.config.default_docker_image
      @load_balancer_config   = config.delete(:load_balancer_config)
      @predeploy_commands     = config.delete(:predeploy_commands)
      @scale                  = config.delete(:scale)
      @service_config         = config.delete(:service_config)
      @task_definition_config = config.delete(:task_definition_config)

      @env_files = Array.wrap(config.delete(:env_files) || config.delete(:env_file)).map do |env_path|
        env_file = Pathname.new(env_path)
        next env_file if env_file.absolute?

        dir = Broadside.config.config_file ? Pathname.new(Broadside.config.config_file).dirname : Dir.pwd
        env_file.expand_path(dir)
      end

      raise ConfigurationError, errors.full_messages unless valid?
      warn "Target #{@name} was configured with invalid/unused options: #{config}" unless config.empty?
    end

    def ecs_env_vars
      @env_vars ||= @env_files.inject({}) do |env_variables, env_file|
        raise ConfigurationError, "Specified env_file: '#{env_file}' does not exist!" unless env_file.exist?

        begin
          env_variables.merge(Dotenv.load(env_file))
        rescue Dotenv::FormatError => e
          raise e.class, "Error parsing #{env_file}: #{e.message}", e.backtrace
        end
      end.map { |k, v| { 'name' => k, 'value' => v } }
    end

    def family
      "#{Broadside.config.application}_#{@name}"
    end

    def to_h
      {
        Target: @name,
        Image: "#{@docker_image}:#{@tag || 'no_tag_configured'}",
        Cluster: @cluster
      }
    end
  end
end
