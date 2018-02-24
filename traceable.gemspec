# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Maintain your gem's version:
require 'traceable/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'traceable'
  s.version     = Traceable::VERSION
  s.authors     = ['Jeremy Slade']
  s.email       = ['jeremy@jkslade.net']

  s.summary     = 'Instrument code with logging'
  s.homepage    = 'https://github.com/instructure/inst-jobs-statsd'
  s.license     = 'MIT'

  s.files = Dir['{lib}/**/*']
  s.test_files = Dir['spec/**/*']

  s.required_ruby_version = '>= 2.2'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec', '3.4.0'
  s.add_development_dependency 'rubocop', '~> 0'
  s.add_development_dependency 'simplecov', '~> 0.14'
  s.add_development_dependency 'wwtd', '~> 1.3.0'
end
