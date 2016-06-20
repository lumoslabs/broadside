module Broadside
  class Deploy
    include Utils

    attr_accessor :deploy_config

    def initialize(opts)
      @deploy_config = Broadside.config.deploy.dup
      @deploy_config.tag = opts[:tag]           || @deploy_config.tag
      @deploy_config.target = opts[:target]     || @deploy_config.target
      @deploy_config.verify(:target, :targets)
      @deploy_config.load_target!

      @deploy_config.scale = opts[:scale]       || @deploy_config.scale
      @deploy_config.rollback = opts[:rollback] || @deploy_config.rollback
      @deploy_config.instance = opts[:instance] || @deploy_config.instance
      @deploy_config.command = opts[:command]   || @deploy_config.command
    end

    def short
      deploy
    end

    def full
      run_predeploy
      deploy
    end

    def deploy
      @deploy_config.verify(:tag)
      info "Deploying #{image_tag} to #{family}..."
      yield
      info 'Deployment complete.'
    end

    def rollback(count = @deploy_config.rollback)
      @deploy_config.verify(:rollback)
      info "Rolling back #{@deploy_config.rollback} release for #{family}..."
      yield
      info 'Rollback complete.'
    end

    def scale
      info "Rescaling #{family} with scale=#{@deploy_config.scale}"
      yield
      info 'Rescaling complete.'
    end

    def run
      @deploy_config.verify(:tag, :ssh, :command)
      info "Running command [#{@deploy_config.command}] for #{family}..."
      yield
      info 'Complete.'
    end

    def run_predeploy
      @deploy_config.verify(:tag, :ssh)
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
      @deploy_config.verify(:instance)
      yield
    end

    def ssh
      @deploy_config.verify(:instance)
      yield
    end

    def bash
      @deploy_config.verify(:instance)
      yield
    end

    protected

    def family
      "#{config.base.application}_#{@deploy_config.target}"
    end

    def image_tag
      "#{config.base.docker_image}:#{@deploy_config.tag}"
    end

    def gen_ssh_cmd(ip, options = { tty: false })
      opts = @deploy_config.ssh
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
