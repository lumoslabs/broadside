require 'active_model'
require 'active_support/core_ext'
require 'aws-sdk'

require 'broadside/error'
require 'broadside/logging_utils'
require 'broadside/configuration'
require 'broadside/configuration/aws_config'
require 'broadside/configuration/ecs_config'
require 'broadside/command'
require 'broadside/target'
require 'broadside/deploy'
require 'broadside/predeploy_commands'
require 'broadside/ecs/ecs_deploy'
require 'broadside/ecs/ecs_manager'
require 'broadside/version'

module Broadside
  extend LoggingUtils

  USER_CONFIG_FILE = "#{Dir.home}/.broadside/config.rb"

  def self.configure
    yield config
  end

  def self.load_config(config_file)
    begin
      load USER_CONFIG_FILE if File.exists?(USER_CONFIG_FILE)
    rescue LoadError => e
      error "Encountered an error loading system configuration file '#{USER_CONFIG_FILE}' !"
      raise e
    end

    begin
      config.config_file = config_file
      load config_file
    rescue LoadError => e
      error "Encountered an error loading required configuration file '#{config_file}' !"
      raise e
    end

    raise ArgumentError, config.errors.full_messages unless config.valid?
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
