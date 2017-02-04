module Broadside
  class Deploy
    include LoggingUtils

    attr_reader :command, :tag, :target
    delegate :family, to: :target

    def initialize(target_name, options = {})
      @target = Broadside.config.get_target_by_name!(target_name)
      @tag    = options[:tag] || @target.tag
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

    def rollback(count)
      info "Rolling back #{count} release for #{family}..."
      yield
      info 'Rollback complete.'
    end

    def scale
      info "Rescaling #{family} with scale=#{@scale}..."
      yield
      info 'Rescaling complete.'
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

    def verify(var)
      raise MissingVariableError, "Missing #{self.class.to_s.split('::').last} variable '#{var}'!" if send(var).nil?
    end
  end
end
