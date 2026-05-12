# frozen_string_literal:true

require 'net/http'

class Cutoff
  module Patch
    # Set checkpoints for Ruby HTTP requests. Also sets the Net::HTTP timeouts
    # to the remaining cutoff time. You can select this patch with
    # `exclude` or `only` using the checkpoint name `:net_http`.
    module NetHttp
      class << self
        private

        def gen_timeout_method(name)
          <<~RUBY
            if #{name}.nil? || #{name} > remaining
              self.#{name} = cutoff.seconds_remaining
            end
          RUBY
        end

        def use_write_timeout?
          Gem::Version.new(RUBY_VERSION) > Gem::Version.new('2.6')
        end
      end

      # Same as the original start, but adds a checkpoint for starting HTTP
      # requests and sets network timeouts to the remaining time.
      #
      # Also applies the same logic to begin_transport, which is called on
      # every HTTP attempt including internal retries. Net::HTTP#transport_request
      # silently retries idempotent requests (GET, HEAD, PUT, DELETE, OPTIONS,
      # TRACE) up to max_retries (default 1) on transient errors like
      # Net::ReadTimeout. Without re-applying the cutoff in begin_transport,
      # the retry path goes through #connect (not #start), reuses the original
      # read_timeout, and effectively doubles the deadline you set.
      #
      # @method start
      # @method begin_transport
      # @see Net::HTTP#start
      # @see Net::HTTP#begin_transport
      module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def start
          _cutoff_apply_to_net_http
          super
        end

        def begin_transport(req)
          _cutoff_apply_to_net_http
          super
        end

        private

        def _cutoff_apply_to_net_http
          return unless (cutoff = Cutoff.current) && cutoff.selected?(:net_http)

          remaining = cutoff.seconds_remaining
          #{gen_timeout_method('open_timeout')}
          #{gen_timeout_method('read_timeout')}
          #{gen_timeout_method('write_timeout') if use_write_timeout?}
          #{gen_timeout_method('continue_timeout')}
          Cutoff.checkpoint!(:net_http)
        end
      RUBY
    end
  end
end

# @api external
module Net
  class HTTP
    prepend Cutoff::Patch::NetHttp
  end
end
