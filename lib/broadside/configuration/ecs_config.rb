require 'dry-struct'

module Broadside
  class EcsConfig
    include VerifyInstanceVariables

    # Cluster can be overridden in a Target
    attr_accessor :cluster, :poll_frequency

    def initialize
      @cluster = nil
      @poll_frequency = 2
    end
  end
end
