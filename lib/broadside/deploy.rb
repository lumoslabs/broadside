require 'active_model'
require 'active_support/core_ext/module/delegation'

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
    delegate :family, to: :target

    def initialize(target_name, options = {})
      @target   = Broadside.config.target_from_name!(target_name)
      @command  = options[:command]  || @target.command
      @instance = options[:instance] || 0
      @lines    = options[:lines]    || 10
      @rollback = options[:rollback] || 1
      @scale    = options[:scale]    || @target.scale
      @tag      = options[:tag]      || @target.tag
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

    def image_tag
      verify(:tag)
      "#{@target.docker_image}:#{@tag}"
    end
  end
end
