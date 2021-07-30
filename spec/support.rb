# frozen_string_literal:true

def silence_warnings
  old_verbose = $VERBOSE
  $VERBOSE = nil
  yield
ensure
  $VERBOSE = old_verbose
end
