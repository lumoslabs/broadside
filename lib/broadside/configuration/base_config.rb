require 'logger'

module Broadside
  class Configuration
    class BaseConfig < ConfigStruct
      attr_accessor :application, :docker_image, :logger, :loglevel, :prehook, :posthook

      def initialize
        @application = nil
        @docker_image = nil
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG
        @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
        @prehook = nil
        @posthook = nil
      end
    end
  end
end
