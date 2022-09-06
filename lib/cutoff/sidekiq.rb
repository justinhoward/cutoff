# frozen_string_literal: true

require 'sidekiq'

class Cutoff
  # Cutoff sidekiq extensions
  module Sidekiq
    # Add an option `cutoff` for sidekiq workers
    #
    # @example
    #   class MyWorker
    #     include Sidekiq::Worker
    #
    #     sidekiq_options cutoff: 6.0
    #
    #     def perform
    #       # ...
    #     end
    #   end
    class ServerMiddleware
      # @param _worker [Object] the worker instance
      # @param job [Hash] the full job payload
      # @param _queue [String] queue the name of the queue the job was pulled
      #   from
      # @yield the next middleware in the chain or worker `perform` method
      # @return [void]
      def call(_worker, job, _queue)
        allowed_seconds = job['cutoff']
        return yield if allowed_seconds.nil?

        Cutoff.wrap(allowed_seconds) { yield }
      end
    end
  end
end

::Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add(Cutoff::Sidekiq::ServerMiddleware)
  end
end
