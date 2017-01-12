module Broadside
  class Configuration
    class EcsConfig < ConfigStruct
      attr_accessor :cluster, :poll_frequency

      def initialize
        @cluster = nil
        @poll_frequency = 2
      end
    end
  end
end
