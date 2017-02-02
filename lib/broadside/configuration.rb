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
    validates_each(:ecs) { |record, attr, val| record.errors.add(attr) unless val.poll_frequency }
    validates_each(:aws) do |record, _, val|
      [:region, :credentials].each { |v| record.errors.add("aws.#{v}") unless val.public_send(v) }
    end
    validates_each :ssh, allow_nil: true do |record, attr, val|
      record.errors.add(attr, 'is not a hash') unless val.is_a?(Hash)
      record.errors.add(attr, 'must contain a user') unless val[:user]
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

    def ssh_cmd(ip, options = {})
      raise MissingVariableError, 'ssh not configured' unless @ssh

      cmd = 'ssh -o StrictHostKeyChecking=no'
      cmd << ' -t -t' if options[:tty]
      cmd << " -i #{@ssh[:keyfile]}" if @ssh[:keyfile]
      if (proxy = @ssh[:proxy])
        raise ArgumentError, "Bad proxy: #{proxy[:host]}/#{proxy[:port]}" unless proxy[:host] && proxy[:port]
        cmd << " -o ProxyCommand=\"ssh #{proxy[:host]} nc #{ip} #{proxy[:port]}\""
      end
      cmd << " #{@ssh[:user]}@#{ip}"
      cmd
    end

    # Transform deploy target configs to Target objects
    def targets=(_targets)
      raise ArgumentError, ":targets must be a hash" unless _targets.is_a?(Hash)

      @targets = _targets.inject({}) do |h, (target_name, config)|
        h.merge(target_name => Target.new(target_name, config))
      end
    end

    def get_target_by_name!(name)
      @targets.fetch(name) { |k| raise ArgumentError, "Deploy target '#{name}' does not exist!" }
    end
  end
end
