require 'active_model'
require 'active_support/core_ext'
require 'aws-sdk-ec2'
require 'aws-sdk-ecs'

require 'broadside/error'
require 'broadside/logging_utils'
require 'broadside/configuration/invalid_configuration'
require 'broadside/configuration/configuration'
require 'broadside/configuration/aws_configuration'
require 'broadside/command'
require 'broadside/target'
require 'broadside/deploy'
require 'broadside/ecs/ecs_deploy'
require 'broadside/ecs/ecs_manager'
require 'broadside/version'

module Broadside
  extend LoggingUtils

  USER_CONFIG_FILE = (ENV['BROADSIDE_SYSTEM_CONFIG_FILE'] || File.join(Dir.home, '.broadside', 'config.rb')).freeze

  def self.configure
    yield config
    raise ConfigurationError, config.errors.full_messages unless config.valid?
  end

  def self.load_config_file(config_file)
    raise ArgumentError, "#{config_file} does not exist" unless File.exist?(config_file)
    config.config_file = config_file

    begin
      if File.exist?(USER_CONFIG_FILE)
        debug "Loading user configuration from #{USER_CONFIG_FILE}"

        begin
          load(USER_CONFIG_FILE)
        rescue ConfigurationError
          # Suppress the exception because the system config file can be incomplete and validation failure is expected
        end
      end

      debug "Loading application configuration from #{config_file}"
      load(config_file)
    rescue LoadError
      error 'Encountered an error loading broadside configuration'
      raise
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.reset!
    @config = nil
    EcsManager.instance_variable_set(:@ecs_client, nil)
    EcsManager.instance_variable_set(:@ec2_client, nil)
  end
end
