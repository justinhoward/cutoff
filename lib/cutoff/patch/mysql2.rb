# frozen_string_literal: true

require 'strscan'
require 'mysql2'

class Cutoff
  module Patch
    # Sets the max execution time for SELECT queries if there is an active
    # cutoff and it has time remaining. You can select this patch with
    # `exclude` or `only` using the checkpoint name `:mysql2`.
    module Mysql2
      # Overrides `Mysql2::Client#query` to insert a MAX_EXECUTION_TIME query
      # hint with the remaining cutoff time
      #
      # If the cutoff is already exceeded, the query will not be executed and
      # a {CutoffExceededError} will be raised
      #
      # @see Mysql2::Client#query
      # @raise CutoffExceededError If the cutoff is exceeded. The query will not
      #   be executed in this case.
      def query(sql, options = {})
        cutoff = Cutoff.current
        return super unless cutoff&.selected?(:mysql2)

        cutoff.checkpoint!(:mysql2)
        sql = QueryWithMaxTime.new(sql, cutoff.ms_remaining.ceil).to_s
        super
      end

      # Parses a query and inserts a MAX_EXECUTION_TIME query hint if possible
      #
      # @private
      class QueryWithMaxTime
        def initialize(query, max_execution_time_ms)
          @scanner = StringScanner.new(query.dup)
          @max_execution_time_ms = max_execution_time_ms
          @found_select = false
          @found_hint = false
          @hint_pos = nil
          @insert_space = false
          @insert_trailing_space = false
        end

        def to_s
          return @scanner.string if @scanner.eos?

          # Loop through tokens like "WORD " or "/* "
          while @scanner.scan(/(\S+)\s+/)
            # Get the word part
            handle_token(@scanner[1])
          end

          return @scanner.string unless @found_select

          insert_hint
          @scanner.string
        end

        private

        def hint
          "MAX_EXECUTION_TIME(#{@max_execution_time_ms})"
        end

        def handle_token(token)
          if token.start_with?('--')
            line_comment
          elsif token.start_with?('/*+')
            hint_comment
          elsif token.start_with?('/*')
            block_comment
          elsif token.match?(/^select/i)
            select
          else
            other
          end
        end

        def insert_hint
          @scanner.string.insert(@hint_pos, ' ') if @insert_trailing_space

          if @found_hint
            # If we found an existing hint, insert our new hint there
            @scanner.string.insert(@hint_pos, hint)
          elsif @found_select
            # Otherwise if we found a select, place our hint right after it
            @scanner.string.insert(@hint_pos, "/*+ #{hint} */")
          end

          @scanner.string.insert(@hint_pos, ' ') if @insert_space
        end

        def line_comment
          # \R matches cross-platform newlines
          # so we skip until the end of the line
          @scanner.skip_until(/\R/)
        end

        def block_comment
          # Go back to the beginning of the comment then scan until the end
          # This handles block comments that don't contain whitespace
          @scanner.unscan
          @scanner.skip_until(%r{\*/\s*})
        end

        def hint_comment
          # We can just treat this as a normal block comment if we haven't seen
          # a select yet
          return block_comment unless @found_select

          @found_hint = true
          # Go back to the beginning of the comment
          # This is so we can handle comments that don't have internal
          # whitespace
          @scanner.unscan
          # Now skip past just the start of the comment so we don't detect it
          # on the next line
          @scanner.skip(%r{/\*\+})
          # Scan until the end of the comment
          # Also detect the last word and trailing whitespace if it exists
          @scanner.scan_until(%r{(\S*)(\s*)\*/})
          # Now step back to the beginning of the */
          # If there was trailing whitespace, also subtract that
          # so that we're at the start of the trailing whitespace
          # That's where we want to put our hint
          @hint_pos = @scanner.pos - 2 - @scanner[2].size
          # We only want to insert an extra space to the left of our
          # hint if there was already a hint (it's possible to have an
          # empty hint comment). So check if there was a word there.
          @insert_space = !@scanner[1].empty?

          # Once we find our position, we're done
          @scanner.terminate
        end

        def select
          # If we encounter a select, we're ready to place our hint comment
          @scanner.unscan
          word = @scanner.scan(/\w+/)

          # Make sure our word is actually select
          # We only checked that it starts with select before
          return other unless word.casecmp('select')

          @found_select = true
          @hint_pos = @scanner.pos

          # If the select has space after it, we want to also
          # insert one later
          if @scanner.scan(/\s+/)
            @insert_space = true
          elsif @scanner.scan(/\*/)
            # Handle SELECT* since it needs to have an extra space inserted
            # after the hint comment
            @insert_trailing_space = true
          end
        end

        def other
          # If we encounter any other token, we're done
          # Either we found the select or we found another token
          # that indicates we should not insert a hint
          @scanner.terminate
        end
      end
    end
  end
end

Mysql2::Client.prepend(Cutoff::Patch::Mysql2)
