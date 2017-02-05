require 'logger'

module Broadside
  class Configuration
    include ActiveModel::Model
    include LoggingUtils

    attr_reader :targets
    attr_accessor(
      :application,
      :config_file,
      :default_docker_image,
      :logger,
      :prehook,
      :posthook,
      :ssh,
      :timeout
    )

    validates :application, :targets, :logger, presence: true

    validates_each(:ecs) do |record, attr, val|
      [:credentials, :poll_frequency, :region].each do |property|
        record.errors.add(attr, "invalid #{property}") unless val && val.public_send(property)
      end
    end

    validates_each(:ssh) do |record, attr, val|
      record.errors.add(attr, 'is not a hash') unless val.is_a?(Hash)

      if (proxy = val[:proxy])
        record.errors.add(attr, 'bad proxy config') unless proxy[:host] && proxy[:port] && proxy[:port].is_a?(Integer)
      end
    end

    def initialize
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger::INFO
      @logger.datetime_format = '%Y-%m-%d_%H:%M:%S'
      @ssh = {}
      @timeout = 600
    end

    def ecs
      @ecs ||= EcsConfiguration.new
    end

    def ssh_cmd(ip, options = {})
      cmd = 'ssh -o StrictHostKeyChecking=no'
      cmd << ' -t -t' if options[:tty]
      cmd << " -i #{@ssh[:keyfile]}" if @ssh[:keyfile]
      if (proxy = @ssh[:proxy])
        cmd << ' -o ProxyCommand="ssh -q'
        cmd << " -i #{proxy[:keyfile]}" if proxy[:keyfile]
        cmd << ' '
        cmd << "#{proxy[:user]}@" if proxy[:user]
        cmd << "#{proxy[:host]} nc #{ip} #{proxy[:port]}\""
      end
      cmd << ' '
      cmd << "#{@ssh[:user]}@" if @ssh[:user]
      cmd << ip.to_s
      cmd
    end

    # Transform deploy target configs to Target objects
    def targets=(_targets)
      raise ConfigurationError, ":targets must be a hash" unless _targets.is_a?(Hash)

      @targets = _targets.inject({}) do |h, (target_name, config)|
        h.merge(target_name => Target.new(target_name, config))
      end
    end

    def get_target_by_name!(name)
      @targets.fetch(name) { raise ArgumentError, "Deploy target '#{name}' does not exist!" }
    end
  end
end
