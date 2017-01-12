require 'logger'

module Broadside
  class Configuration
    include VerifyInstanceVariables
    include Utils

    attr_accessor :ecs, :aws, :file
    attr_accessor :application, :docker_image, :logger, :prehook, :posthook, :ssh, :type
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
      warn("config.base is deprecated; configure those options directly")
      self
    end

    def verify
      super(:application, :docker_image)
    end
  end
end
