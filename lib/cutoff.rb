# frozen_string_literal:true

require 'cutoff/version'
require 'cutoff/error'
require 'cutoff/patch'
require 'cutoff/timer'

require 'cutoff/rails'
require 'cutoff/sidekiq' if Gem.loaded_specs['sidekiq']

class Cutoff
  CURRENT_STACK_KEY = 'cutoff_deadline_stack'
  private_constant :CURRENT_STACK_KEY

  extend Timer

  class << self
    # Get the current {Cutoff} if one is set
    def current
      Thread.current[CURRENT_STACK_KEY]&.last
    end

    # Add a new {Cutoff} to the stack
    #
    # This {Cutoff} will be specific to this thread
    #
    # If a cutoff is already started for this thread, then `start` uses the
    # minimum of the current remaining time and the given time
    #
    # @param seconds [Float, Integer] The number of seconds for the cutoff. May
    #   be overridden if there is an active cutoff and it has less remaining
    #   time.
    # @return [Cutoff] The {Cutoff} instance
    def start(seconds)
      seconds = [seconds, current.seconds_remaining].min if current
      cutoff = Cutoff.new(seconds)
      Thread.current[CURRENT_STACK_KEY] ||= []
      Thread.current[CURRENT_STACK_KEY] << cutoff
      cutoff
    end

    # Remove the top {Cutoff} from the stack
    #
    # @param cutoff [Cutoff] If given, the top instance will only be removed
    #   if it matches the given cutoff instance
    # @return [Cutoff, nil] If a cutoff was removed it is returned
    def stop(cutoff = nil)
      stack = Thread.current[CURRENT_STACK_KEY]
      return unless stack

      top = stack.last
      stack.pop if cutoff.nil? || top == cutoff
      clear_all if stack.empty?

      cutoff
    end

    # Clear the entire stack for this thread
    #
    # @return [void]
    def clear_all
      Thread.current[CURRENT_STACK_KEY] = nil
    end

    # Wrap a block in a cutoff
    #
    # Same as calling {.start} and {.stop} manually, but safer since
    # you can't forget to stop a cutoff and it handles exceptions raised
    # inside the block
    #
    # @see .start
    # @see .stop
    # @return The value that returned from the block
    def wrap(seconds)
      cutoff = start(seconds)
      yield cutoff
    ensure
      stop(cutoff)
    end

    # Raise an exception if there is an active expired cutoff
    #
    # Does nothing if no active cutoff is set
    #
    # @raise CutoffExceededError If there is an active expired cutoff
    # @return [void]
    def checkpoint!
      cutoff = current
      return unless cutoff

      cutoff.checkpoint!
    end

    # Disable Cutoff globally. Useful for testing and debugging
    #
    # Should not be used in production
    #
    # @return [void]
    def disable!
      @disabled = true
    end

    # Enable Cutoff globally if it has been disabled
    #
    # Should not be used in production
    #
    # @return [void]
    def enable!
      @disabled = false
    end

    # True if cutoff was disabled with {#disable!}
    #
    # @return [Boolean] True if disabled
    def disabled?
      @disabled == true
    end
  end

  # @return [Float] The total number of seconds for this cutoff
  attr_reader :allowed_seconds

  # Create a new cutoff
  #
  # The timer starts immediately upon creation
  #
  # @param allowed_seconds [Integer, Float] The total number of seconds to allow
  def initialize(allowed_seconds)
    @allowed_seconds = allowed_seconds.to_f
    @start_time = Cutoff.now
  end

  # The number of seconds left on the clock
  #
  # @return [Float] The number of seconds
  def seconds_remaining
    @allowed_seconds - elapsed_seconds
  end

  # The number of milliseconds left on the clock
  #
  # @return [Float] The number of milliseconds
  def ms_remaining
    seconds_remaining * 1000
  end

  # The number of seconds elapsed since this {Cutoff} was created
  #
  # @return [Float] The number of seconds
  def elapsed_seconds
    return 0 if Cutoff.disabled?

    Cutoff.now - @start_time
  end

  # Has the Cutoff been exceeded?
  #
  # @return [Boolean] True if the timer expired
  def exceeded?
    seconds_remaining.negative?
  end

  # Raises an error if this Cutoff has been exceeded
  #
  # @raise CutoffExceededError If there is an active expired cutoff
  # @return [void]
  def checkpoint!
    raise CutoffExceededError, self if exceeded?

    nil
  end
end
