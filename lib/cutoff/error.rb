# frozen_string_literal:true

class Cutoff
  # The Cutoff base error class
  class CutoffError < StandardError
    private

    def message_with_meta(message, **meta)
      "#{message}: #{format_meta(**meta)}"
    end

    def format_meta(**meta)
      meta.map { |key, value| "#{key}=#{value}" }.join(' ')
    end
  end

  # Raised by {Cutoff#checkpoint!} if the time has been exceeded
  class CutoffExceededError < CutoffError
    attr_reader :cutoff

    def initialize(cutoff)
      @cutoff = cutoff

      super(message_with_meta(
        'Cutoff exceeded',
        allowed_seconds: cutoff.allowed_seconds,
        elapsed_seconds: cutoff.elapsed_seconds
      ))
    end
  end
end
