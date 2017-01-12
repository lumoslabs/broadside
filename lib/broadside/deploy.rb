module Broadside
  class Deploy
    include Utils
    include VerifyInstanceVariables

    attr_reader(
      :command,
      :instance,
      :lines,
      :tag,
      :target
    )

    def initialize(target, opts = {})
      @target   = target
      @command  = opts[:command]
      @instance = opts[:instance] || @target.instance
      @lines    = opts[:lines]    || 10
      @rollback = opts[:rollback] || 1
      @scale    = opts[:scale]    || @target.scale
      @tag      = opts[:tag]
    end

    def short
      deploy
    end

    def full
      run_predeploy
      deploy
    end

    def deploy
      verify(:tag)
      info "Deploying #{image_tag} to #{family}..."
      yield
      info 'Deployment complete.'
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
      config.verify(:ssh)
      verify(:tag, :command)
      info "Running command [#{@command}] for #{family}..."
      yield
      info 'Complete.'
    end

    def run_predeploy
      config.verify(:ssh)
      verify(:tag)
      info "Running predeploy commands for #{family}..."
      yield
      info 'Predeploy complete.'
    end

    def status
      info "Getting status information about #{family}"
      yield
      info 'Complete.'
    end

    def logtail
      verify(:instance)
      yield
    end

    def ssh
      verify(:instance)
      yield
    end

    def bash
      verify(:instance)
      yield
    end

    protected

    def family
      "#{config.application}_#{@target.name}"
    end

    def image_tag
      "#{config.docker_image}:#{@tag}"
    end

    def gen_ssh_cmd(ip, options = { tty: false })
      opts = @target.ssh || {}
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
