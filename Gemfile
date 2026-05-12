# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# We add non-essential gems like debugging tools and CI dependencies
# here. This also allows us to use conditional dependencies that depend on the
# platform

not_jruby = %i[ruby windows].freeze

gem 'actionpack'
gem 'byebug', platforms: not_jruby
gem 'irb', '~> 1.0'
# Minimum of 0.5.0 for specific error classes
gem 'mysql2', '>= 0.5.0', platforms: not_jruby
gem 'redcarpet', '~> 3.5', platforms: not_jruby
gem 'sidekiq', '>= 5'
# 0.8 is incompatible with simplecov < 0.18
# https://github.com/fortissimo1997/simplecov-lcov/pull/25
gem 'simplecov-lcov', '~> 0.7', '< 0.8'
gem 'yard', '~> 0.9.25', platforms: not_jruby

gem 'concurrent-ruby'

gem 'rubocop', '1.34.1'
gem 'rubocop-rspec', '2.12'
gem 'simplecov', '~> 0.21.0'
gem 'simplecov-cobertura', '~> 3.1'

# simplecov-cobertura crashes with REXML::ParseException: Malformed XML on
# rexml >= 3.4.2. https://github.com/jessebs/simplecov-cobertura/issues/48
gem 'rexml', '< 3.4.2'
