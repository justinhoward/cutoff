# frozen_string_literal: true

require 'byebug' if Gem.loaded_specs['byebug']

if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  if ENV['CI']
    require 'simplecov-lcov'
    SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
    SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
  end

  SimpleCov.start do
    if Gem::Version.new(SimpleCov::VERSION) >= Gem::Version.new('0.18.0')
      enable_coverage :branch
    end
    add_filter '/spec/'
    add_filter '/vendor/'
  end
end

require 'cutoff'
require 'timecop'
require 'cutoff/patch/net_http'

begin
  # We don't test Mysql2 on Ruby 2.3 since that would require
  # installing an old EOL version of OpenSSL
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4')
    require 'cutoff/patch/mysql2'
  end
rescue LoadError
  # Ok if mysql2 isn't available
end

require_relative 'support'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.warnings = false

  config.before do
    # Use Time.now for tests instead of process time to allow Timecop to work
    allow(Process).to receive(:clock_gettime) { |*| Time.now.to_f }
  end

  config.after do
    Timecop.return
    Cutoff.clear_all
  end
end
