# frozen_string_literal: true

require 'action_controller'

class Cutoff
  # Cutoff Rails extensions
  module Rails
    # Rails controller integration
    module Controller
      # Set a cutoff for the controller
      #
      # Can be called multiple times with different options to configure
      # cutoffs for various conditions. If multiple conditions match a given
      # controller, the last applied cutoff "wins".
      #
      # @example
      #   class ApplicationController
      #     # Apply a global maximum
      #     cutoff 30
      #   end
      #
      #   class UsersController < ApplicationController
      #     # Override the base time limit
      #     cutoff 5.0
      #     cutoff 3.0, only: :show
      #     cutoff 7, if: :signed_in
      #   end
      #
      # @param seconds [Float, Integer] The allowed seconds for a controller
      #   action
      # @param options [Hash] Options to pass to `around_action`. For example,
      #   pass `:only`, `:except`, `:if`, to limit the scope of the cutoff.
      def cutoff(seconds, options = {})
        prepend_around_action(options) do |_controller, action|
          next action.call if @cutoff_wrapped

          begin
            @cutoff_wrapped = true
            Cutoff.wrap(seconds, &action)
          ensure
            @cutoff_wrapped = false
          end
        end
      end
    end
  end
end

# @api external
module ActionController
  class Base
    extend Cutoff::Rails::Controller
  end
end
