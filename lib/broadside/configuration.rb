require 'logger'

module Broadside
  class Configuration
    extend Gem::Deprecate
    include VerifyInstanceVariables
    include Utils

    # Sub configs
    attr_accessor :ecs, :aws
    attr_accessor :application, :docker_image, :file, :logger, :prehook, :posthook, :ssh, :type
    attr_reader :targets

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
    end

    def aws
      @aws ||= AwsConfig.new
    end

    def ecs
      @ecs ||= EcsConfig.new
    end

    def targets=(_targets)
      @targets = _targets.map { |name, config| Target.new(name, config) }
    end

    # Maintain backward compatibility
    def base
      self
    end
    deprecate :base, 'config.base.option should be configured directly as config.option', 2017, 4

    def deploy
      raise ArgumentError, 'config.deploy was removed in Broadside 2.0'
    end

    def verify
      super(:application, :docker_image)
    end
  end
end
