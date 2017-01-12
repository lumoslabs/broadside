module Broadside
  class Deploy
    include Utils

    attr_reader :target

    def initialize(target, opts = {})
      @target = target
      @tag = opts[:tag]
      @scale = opts[:scale]       || @target.scale
      @rollback = opts[:rollback] || 1
      @instance = opts[:instance] || @target.instance
      @command = opts[:command]   || @target.command
      @lines = opts[:lines]       || 10
    end

    def short
      deploy
    end

    def full
      run_predeploy
      deploy
    end

    def deploy
      @target.verify(:tag)
      info "Deploying #{image_tag} to #{family}..."
      yield
      info 'Deployment complete.'
    end

    def rollback(count = @target.rollback)
      @target.verify(:rollback)
      info "Rolling back #{@target.rollback} release for #{family}..."
      yield
      info 'Rollback complete.'
    end

    def scale
      info "Rescaling #{family} with scale=#{@target.scale}"
      yield
      info 'Rescaling complete.'
    end

    def run
      @target.verify(:tag, :ssh, :command)
      info "Running command [#{@target.command}] for #{family}..."
      yield
      info 'Complete.'
    end

    def run_predeploy
      @target.verify(:tag, :ssh)
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
      @target.verify(:instance)
      yield
    end

    def ssh
      @target.verify(:instance)
      yield
    end

    def bash
      @target.verify(:instance)
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
