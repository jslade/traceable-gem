# frozen_string_literal: true

require 'logger'

module Traceable
  class Config
    attr_accessor :default_tags
    attr_accessor :logger

    def initialize
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

      @default_tags = {}
    end
  end

  def self.configure(&_)
    yield config
  end

  def self.config
    @config ||= Config.new
  end
end
