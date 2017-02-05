require 'active_model'
require 'active_support/core_ext'
require 'aws-sdk'

require 'broadside/error'
require 'broadside/logging_utils'
require 'broadside/configuration/configuration'
require 'broadside/configuration/ecs_configuration'
require 'broadside/command'
require 'broadside/target'
require 'broadside/deploy'
require 'broadside/ecs/ecs_deploy'
require 'broadside/ecs/ecs_manager'
require 'broadside/version'

module Broadside
  extend LoggingUtils

  USER_CONFIG_FILE = "#{Dir.home}/.broadside/config.rb"

  def self.configure
    yield config
    raise ConfigurationError, config.errors.full_messages unless config.valid?
  end

  def self.load_config(config_file)
    raise ConfigurationError, "#{config_file} does not exist" unless File.exist?(config_file)
    config.config_file = config_file

    begin
      if File.exist?(USER_CONFIG_FILE)
        debug "Loading user configuration from #{USER_CONFIG_FILE}"

        begin
          load(USER_CONFIG_FILE)
        rescue ConfigurationError
          # Rescue because the user/system config file can be incomplete and validation failure is ok.
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
