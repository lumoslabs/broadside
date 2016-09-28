require 'broadside/error'
require 'broadside/utils'
require 'broadside/configuration'
require 'broadside/configuration/struct'
require 'broadside/configuration/aws'
require 'broadside/configuration/base'
require 'broadside/configuration/deploy_config'
require 'broadside/configuration/ecs_config'
require 'broadside/deploy'
require 'broadside/deploy/ecs_deploy'
require 'broadside/deploy/ecs_manager'
require 'broadside/version'

module Broadside
  extend Utils

  SYSTEM_CONFIG_FILE = "#{Dir.home}/.broadside/config.rb"

  def self.configure
    yield config
  end

  def self.load_config(config_file)
    begin
      load SYSTEM_CONFIG_FILE if File.exists?(SYSTEM_CONFIG_FILE)
    rescue LoadError => e
      error "Encountered an error loading system configuration file '#{SYSTEM_CONFIG_FILE}' !"
      raise e
    end

    begin
      load config_file
      config.file = config_file
    rescue LoadError => e
      error "Encountered an error loading required configuration file '#{config_file}' !"
      raise e
    end

    config.verify
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.reset!
    @config = nil
  end
end
