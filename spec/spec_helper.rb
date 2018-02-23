# frozen_string_literal: true

if /^2\.4/ =~ RUBY_VERSION # Limit coverage to one build
  require 'simplecov'

  SimpleCov.start do
    add_filter 'lib/traceable/version.rb'
    add_filter 'spec'
    track_files 'lib/**/*.rb'
  end

  SimpleCov.minimum_coverage(100)
end

require 'traceable'

require 'byebug'
require 'pry'

RSpec.configure do |config|
  config.expect_with(:rspec) do |c|
    c.syntax = %i[should expect]
  end

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  config.order = :random
  Kernel.srand config.seed
end
