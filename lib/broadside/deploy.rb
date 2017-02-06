module Broadside
  class Deploy
    include LoggingUtils

    attr_reader :target
    delegate :cluster, to: :target
    delegate :family, to: :target

    def initialize(target_name, options = {})
      @target = Broadside.config.get_target_by_name!(target_name)
      @tag = options[:tag] || @target.tag
    end

    private

    def image_tag
      raise ArgumentError, 'Missing tag!' unless @tag
      "#{@target.docker_image}:#{@tag}"
    end
  end
end
