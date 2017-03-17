module Broadside
  class Deploy
    include LoggingUtils

    attr_reader :target

    delegate :tag, to: :target

    def initialize(options = {})
      @target = Broadside.config.get_target_by_name!(options[:target])
      @target.tag = options[:tag] if options[:tag]
    end

    private

    def image_tag
      raise ArgumentError, 'Missing tag!' unless @tag
      "#{@target.docker_image}:#{@tag}"
    end
  end
end
