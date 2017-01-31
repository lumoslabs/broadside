require 'active_model'

module Broadside
  class Deploy
    include LoggingUtils
    include VerifyInstanceVariables

    attr_reader(
      :command,
      :instance,
      :lines,
      :tag,
      :target
    )

    def initialize(target, options = {})
      @target   = target
      @command  = options[:command]  || @target.command
      @instance = options[:instance] || 0
      @lines    = options[:lines]    || 10
      @rollback = options[:rollback] || 1
      @scale    = options[:scale]    || @target.scale
      @tag      = options[:tag]
    end

    def short
      deploy
    end

    def full
      info "Running predeploy commands for #{family}..."
      run_commands(@target.predeploy_commands)
      info 'Predeploy complete.'

      deploy
    end

    def rollback(count = @rollback)
      info "Rolling back #{count} release for #{family}..."
      yield
      info 'Rollback complete.'
    end

    def scale
      info "Rescaling #{family} with scale=#{@scale}"
      yield
      info 'Rescaling complete.'
    end

    def run
      verify(:command)
      yield
    end

    def status
      info "Getting status information about #{family}"
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

    private

    def deploy
      info "Deploying #{image_tag} to #{family}..."
      yield
      info 'Deployment complete.'
    end

    def family
      "#{Broadside.config.application}_#{@target.name}"
    end

    def image_tag
      verify(:tag)
      "#{@target.docker_image}:#{@tag}"
    end

    def gen_ssh_cmd(ip, options = { tty: false })
      opts = Broadside.config.ssh || {}
      cmd = 'ssh -o StrictHostKeyChecking=no'
      cmd << ' -t -t' if options[:tty]
      cmd << " -i #{opts[:keyfile]}" if opts[:keyfile]
      if opts[:proxy]
        cmd << " -o ProxyCommand=\"ssh #{opts[:proxy][:host]} nc #{ip} #{opts[:proxy][:port]}\""
      end
      cmd << " #{opts[:user]}@#{ip}"
      cmd
    end
  end
end
