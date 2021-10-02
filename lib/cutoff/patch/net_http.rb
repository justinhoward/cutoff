# frozen_string_literal:true

require 'net/http'

class Cutoff
  module Patch
    module NetHttp
      def self.gen_timeout_method(name)
        <<~RUBY
          if #{name}.nil? || #{name} > remaining
            self.#{name} = cutoff.seconds_remaining
          end
        RUBY
      end

      def self.use_write_timeout?
        Gem::Version.new(RUBY_VERSION) > Gem::Version.new('2.6')
      end

      # Same as the original start, but adds a checkpoint for starting HTTP
      # requests and sets network timeouts to the remaining time
      #
      # @see Net::HTTP#start
      module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def start
          if (cutoff = Cutoff.current)
            remaining = cutoff.seconds_remaining
            #{gen_timeout_method('open_timeout')}
            #{gen_timeout_method('read_timeout')}
            #{gen_timeout_method('write_timeout') if use_write_timeout?}
            #{gen_timeout_method('continue_timeout')}
            Cutoff.checkpoint!
          end
          super
        end
      RUBY
    end
  end
end

Net::HTTP.prepend(Cutoff::Patch::NetHttp)
