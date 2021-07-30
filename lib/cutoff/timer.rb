# frozen_string_literal:true

class Cutoff
  module Timer
    if defined?(Process::CLOCK_MONOTONIC_RAW)
      # The current time
      #
      # If it is available, this will use a monotonic clock. This is a clock
      # that always moves forward in time. If that is not available on this
      # system, `Time.now` will be used
      #
      # @return [Float] The current time as a float
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC_RAW)
      end
    elsif defined?(Process::CLOCK_MONOTONIC)
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
