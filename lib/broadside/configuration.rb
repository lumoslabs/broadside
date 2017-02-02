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

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
      @timeout = 600
      @type = 'ecs'
      @ssh = {}
      @targets = {}
    end

    def aws
      @aws ||= AwsConfig.new
    end

    def ecs
      @ecs ||= EcsConfig.new
    end

    def ssh_cmd(ip, options = { tty: false })
      cmd = 'ssh -o StrictHostKeyChecking=no'
      cmd << ' -t -t' if options[:tty]
      cmd << " -i #{@ssh[:keyfile]}" if @ssh[:keyfile]
      if (proxy = @ssh[:proxy])
        raise ArgumentError, "Bad proxy host/port: #{proxy[:host]}/#{proxy[:port]}" unless proxy[:host] && proxy[:port]
        cmd << " -o ProxyCommand=\"ssh #{proxy[:host]} nc #{ip} #{proxy[:port]}\""
      end
      cmd << " #{@ssh[:user]}@#{ip}"
      cmd
    end

    def targets=(_targets)
      raise ArgumentError, ":targets must be a hash" unless _targets.is_a?(Hash)
      # transform deploy target configs to target objects
      @targets = _targets.inject({}) do |h, (target_name, config)|
        h[target_name] = Target.new(target_name, config)
        h
      end
    end

    def target_from_name!(name)
      @targets.fetch(name) { |k| raise Error, "Deploy target '#{name}' does not exist!" }
    end
  end
end
