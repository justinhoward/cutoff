# frozen_string_literal:true

def silence_warnings
  old_verbose = $VERBOSE
  $VERBOSE = nil
  yield
ensure
  $VERBOSE = old_verbose
end

class TestRailsApp < Rails::Application
  config.secret_key_base = 'secret'
end

Sidekiq::Testing.server_middleware do |chain|
  chain.add(Cutoff::Sidekiq::ServerMiddleware)
end
