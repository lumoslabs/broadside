require 'logger'

module Broadside
  class Configuration
    include VerifyInstanceVariables
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
      if @ssh[:proxy]
        cmd << " -o ProxyCommand=\"ssh #{@ssh[:proxy][:host]} nc #{ip} #{@ssh[:proxy][:port]}\""
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

    def target_from_name!(target_name)
      if target_exists?(target_name)
        @targets[target_name]
      else
        raise Error, "Deploy target '#{target_name}' does not exist!"
      end
    end

    def target_exists?(target_name)
      @targets.has_key?(target_name)
    end

    def verify(*args)
      super(*([:application] + args))
    end
  end
end
