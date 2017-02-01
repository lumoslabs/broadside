require 'logger'

module Broadside
  class Configuration
    include ActiveModel::Model
    include LoggingUtils

    attr_reader(
      :targets,
      :type
    )
    attr_accessor(
      :application,
      :config_file,
      :docker_image,
      :logger,
      :prehook,
      :posthook,
      :ssh,
      :timeout
    )

    validates :application, :targets, :logger, presence: true

    validates_each :ecs do |record, attr ,val|
      record.errors.add(attr, 'not set') unless val.poll_frequency
    end

    validates_each :aws do |record, _, val|
      record.errors.add('aws.region', 'not set') unless val.region
      record.errors.add('aws.credentials', 'not set') unless val.credentials
    end

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
      @timeout = 600
      @type = 'ecs'
    end

    def aws
      @aws ||= AwsConfig.new
    end

    def ecs
      @ecs ||= EcsConfig.new
    end

    def targets=(_targets)
      raise ArgumentError, ":targets must be a hash" unless _targets.is_a?(Hash)
      @targets = _targets.map { |name, config| Target.new(name, config) }
    end
  end
end
