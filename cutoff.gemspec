# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cutoff/version'

Gem::Specification.new do |spec|
  spec.name = 'cutoff'
  spec.version = Cutoff.version
  spec.authors = ['Justin Howard']
  spec.email = ['jmhoward0@gmail.com']
  spec.licenses = ['MIT']

  spec.summary = 'Deadlines for ruby'
  spec.homepage = 'https://github.com/justinhoward/cutoff'

  rubydoc = 'https://www.rubydoc.info/gems'
  spec.metadata = {
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'documentation_uri' => "#{rubydoc}/#{spec.name}/#{spec.version}"
  }

  spec.files = Dir['lib/**/*.rb', '*.md', '*.txt', '.yardopts']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3'

  # 0.81 is the last rubocop version with Ruby 2.3 support
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'rubocop', '0.81.0'
  spec.add_development_dependency 'rubocop-rspec', '1.38.1'
  spec.add_development_dependency 'timecop', '>= 0.9', '< 1.0'
end
