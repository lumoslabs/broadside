require 'logger'

module Broadside
  class Configuration
    include VerifyInstanceVariables
    include LoggingUtils

    attr_reader(
      :targets,
      :type
    )
    attr_accessor(
      :application,
      :config_file,
      :docker_image,
      :logger,
      :prehook,
      :posthook,
      :ssh,
      :timeout
    )

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
      @timeout = 600
      @type = 'ecs'
    end

    def aws
      @aws ||= AwsConfig.new
    end

    def ecs
      @ecs ||= EcsConfig.new
    end

    def targets=(_targets)
      raise ArgumentError, "Targets must be a hash" unless _targets.is_a?(Hash)
      @targets = _targets.map { |name, config| Target.new(name, config) }
    end

    def verify(*args)
      super(*([:application, :docker_image] + args))
    end
  end
end
