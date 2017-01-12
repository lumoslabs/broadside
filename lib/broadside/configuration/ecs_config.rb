module Broadside
  class Configuration
    class EcsConfig < ConfigStruct
      extend Gem::Deprecate

      attr_accessor :cluster, :poll_frequency
      deprecate(
        :cluster=,
        'You should configure the cluster on a per target basis',
        2017,
        4
      )


      def initialize
        @cluster = nil
        @poll_frequency = 2
      end
    end
  end
end
