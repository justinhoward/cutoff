# frozen_string_literal:true

class Cutoff
  # Tracks the current time for cutoff
  module Timer
    if defined?(Process::CLOCK_MONOTONIC)
      # The current relative time
      #
      # If it is available, this will use a monotonic clock. This is a clock
      # that always moves forward in time and starts at an arbitrary point
      # (such as system startup time). If that is not available on this system,
      # `Time.now` will be used.
      #
      # This does not represent current real time
      #
      # @return [Float] The current relative time as a float
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    elsif Gem.loaded_specs['concurrent-ruby']
      require 'concurrent-ruby'

      def now
        Concurrent.monotonic_time
      end
    else
      def now
        Time.now.to_f
      end
    end
  end
end
