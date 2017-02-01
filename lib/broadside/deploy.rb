module Broadside
  class Deploy
    include LoggingUtils

    attr_reader :command, :tag, :target

    def initialize(target, options = {})
      @target   = target
      @command  = options[:command]  || @target.command
      @instance = options[:instance] || 0
      @lines    = options[:lines]    || 10
      @rollback = options[:rollback] || 1
      @scale    = options[:scale]    || @target.scale
      @tag      = options[:tag]      || @target.tag
      verify(:target)
    end

    def short
      deploy
    end

    def full
      info "Running predeploy commands for #{family}..."
      run_commands(@target.predeploy_commands, started_by: 'predeploy')
      info 'Predeploy complete.'

      deploy
    end

    # The `yield` calls are a little weird but this was designed with an eye towards supporting other docker
    # based systems beyond ECS.  That day hasn't come yet, but we didn't think it was worth undoing the structure.

    def rollback(count = @rollback)
      info "Rolling back #{count} release for #{family}..."
      yield
      info 'Rollback complete.'
    end

    def scale
      info "Rescaling #{family} with scale=#{@scale}..."
      yield
      info 'Rescaling complete.'
    end

    def run
      verify(:command)
      info "Running #{command}..."
      yield
    end

    def status
      info "Status information about #{family}:"
      yield
    end

    def logtail
      yield
    end

    def ssh
      yield
    end

    def bash
      yield
    end

    def family
      "#{Broadside.config.application}_#{@target.name}"
    end

    private

    def deploy
      info "Deploying #{image_tag} to #{family}..."
      yield
      info 'Deployment complete.'
    end

    def image_tag
      verify(:tag)
      "#{@target.docker_image}:#{@tag}"
    end

    def gen_ssh_cmd(ip, options = {})
      opts = Broadside.config.ssh || {}
      cmd = 'ssh -o StrictHostKeyChecking=no'
      cmd << ' -t -t' if options[:tty]
      cmd << " -i #{opts[:keyfile]}" if opts[:keyfile]
      if (proxy = opts[:proxy])
        raise ArgumentError, "Bad proxy host/port: #{proxy[:host]}/#{proxy[:port]}" unless proxy[:host] && proxy[:port]
        cmd << " -o ProxyCommand=\"ssh #{proxy[:host]} nc #{ip} #{proxy[:port]}\""
      end
      cmd << " #{opts[:user]}@#{ip}"
      cmd
    end

    def verify(var)
      raise MissingVariableError, "Missing #{self.class.to_s.split("::").last} variable '#{var}'!" if send(var).nil?
    end
  end
end
