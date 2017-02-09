module Broadside
  class Deploy
    include LoggingUtils

    attr_reader :target

    def initialize(options = {})
      @target = Broadside.config.get_target_by_name!(options[:target])
      @tag = options[:tag] || @target.tag
    end

    private

    def image_tag
      raise ArgumentError, 'Missing tag!' unless @tag
      "#{@target.docker_image}:#{@tag}"
    end
  end
end
