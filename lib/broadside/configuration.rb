require 'logger'

module Broadside
  class Configuration
    extend Gem::Deprecate
    include VerifyInstanceVariables
    include Utils

    attr_reader :targets
    attr_accessor(
      :application,
      :config_file,
      :docker_image,
      :logger,
      :prehook,
      :posthook,
      :ssh,
      :timeout,
      :type
    )

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
      @timeout = 600
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

    def git_repo=(_)
      @logger.warn("Assigning :git_repo does nothing.")
    end

    # Maintain backward compatibility
    def deploy
      self
    end
    deprecate :deploy, 'config.deploy.option should be configured directly as config.option', 2017, 4

    def base
      self
    end
    deprecate :base, 'config.base.option should be configured directly as config.option', 2017, 4
  end
end
