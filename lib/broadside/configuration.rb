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
    validates_each(:ecs) do |record, attr, val|
      record.errors.add(attr, "invalid poll_frequency") unless val && val.poll_frequency.is_a?(Fixnum)
    end
    validates_each(:aws) do |record, attr, val|
      [:region, :credentials].each do |v|
        record.errors.add(attr, "invalid #{v}") unless val && val.public_send(v)
      end
    end
    validates_each :ssh, allow_nil: true do |record, attr, val|
      record.errors.add(attr, 'is not a hash') unless val.is_a?(Hash)
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
        raise MissingVariableError, "Bad proxy: #{proxy[:host]}/#{proxy[:port]}" unless proxy[:host] && proxy[:port]
        cmd << " -o ProxyCommand=\"ssh #{proxy[:host]} nc #{ip} #{proxy[:port]}\""
      end
      cmd << ' '
      cmd << "#{@ssh[:user]}@" if @ssh[:user]
      cmd << ip.to_s
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
      @targets.fetch(name) { raise ArgumentError, "Deploy target '#{name}' does not exist!" }
    end
  end
end
