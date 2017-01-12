require 'logger'

module Broadside
  class Configuration
    include ConfigStruct
    include Utils

    attr_accessor :ecs, :aws, :file
    attr_accessor :application, :docker_image, :logger, :loglevel, :prehook, :posthook, :ssh, :type
    attr_accessor :logger
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

    def verify
      @base.verify(:application, :docker_image)
    end
  end
end
