module Broadside
  class EcsConfig
    include ConfigStruct

    attr_accessor :cluster, :poll_frequency

    def initialize
      @cluster = nil
      @poll_frequency = 2
    end
  end
end
