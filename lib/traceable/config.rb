# frozen_string_literal: true

require 'logger'

module Traceable
  class Config
    attr_accessor :default_tags
    attr_accessor :logger
    attr_accessor :max_string_length
    attr_accessor :max_array_values
    attr_accessor :max_hash_keys

    def initialize
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

      @default_tags = {}

      @max_string_length = Args::MAX_STRING_LENGTH
      @max_array_values = Args::MAX_ARRAY_VALUES
      @max_hash_keys = Args::MAX_HASH_KEYS
    end
  end

  def self.configure(&_)
    yield config
    update_args_config
    config
  end

  def self.config
    @config ||= Config.new
  end

  def self.update_args_config
    Args.set_config_limits(
      max_string_length: config.max_string_length,
      max_array_values: config.max_array_values,
      max_hash_keys: config.max_hash_keys
    )
  end
end
