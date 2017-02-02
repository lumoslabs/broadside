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
    raise ArgumentError, "#{config_file} does not exist" unless File.exist?(config_file)

    config.config_file = config_file
    begin
      [config_file, USER_CONFIG_FILE].each { |file| load file if File.exist?(file) }
    rescue LoadError
      error "Encountered an error loading broadside Configuration"
      raise
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
