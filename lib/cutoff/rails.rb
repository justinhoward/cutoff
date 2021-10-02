# frozen_string_literal: true

# Namespace for Rails integration
module Rails
end

require 'cutoff/rails/controller' if Gem.loaded_specs['actionpack']
