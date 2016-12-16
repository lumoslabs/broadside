module Broadside
  class Configuration
    include Utils

    attr_accessor :base, :deploy, :ecs, :aws, :file

    def initialize
      @base = BaseConfig.new
    end

    def deploy
      @deploy ||= Targets.new
    end

    def aws
      @aws ||= AwsConfig.new
    end

    def ecs
      @ecs ||= EcsConfig.new
    end

    def verify
      @base.verify(:application, :docker_image)
    end

    def method_missing(m, *args, &block)
      warn "Unknown configuration '#{m}' provided, ignoring. Check your version of broadside?"
      ConfigStruct.new
    end
  end
end
