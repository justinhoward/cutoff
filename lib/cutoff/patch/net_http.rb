# frozen_string_literal:true

require 'net/http'

class Cutoff
  module Patch
    # Adds a checkpoint for starting HTTP requests and sets network timeouts
    # to the remaining time
    module NetHttp
      # Construct a {Net::HTTP}, but with the timeouts set to the remaining
      # cutoff time if one is active
      def initialize(address, port = nil)
        super
        return unless (cutoff = Cutoff.current)

        @open_timeout = cutoff.seconds_remaining
        @read_timeout = cutoff.seconds_remaining
        @write_timeout = cutoff.seconds_remaining
      end

      # Same as the original start, but with a cutoff checkpoint
      #
      # @see {Net::HTTP#start}
      def start
        Cutoff.checkpoint!
        super
      end
    end
  end
end

Net::HTTP.prepend(Cutoff::Patch::NetHttp)
