# frozen_string_literal: true

require 'securerandom'

module Traceable
  # A module for enhanced logging facilities.
  #
  # The intent of the Traceable functionality is to have log
  # messages that provide runtime diagnostics as well as
  # code documentation.

  # Generate a log message
  # When called without a block, generates a single log message:
  #
  #     trace "this is a single message"
  #     trace.error "something bad happened"
  #
  # When called with a block, the given message is used to compose
  # a log output at the entry and exit of the block.
  #
  #     trace "doing something nifty" do
  #        do_something
  #     end
  def trace(msg = nil, **tags)
    tracer = local_tracer

    if block_given?
      tracer.do_block(msg, **tags) { yield }
    elsif msg
      tracer.info msg, **tags
    else
      tracer
    end
  end

  def local_tracer
    @tracer ||= init_tracer
  end

  # Create the tracer instance used for generating log messages.
  # If a parent is givent, tags and other settings will be
  # inherited from it. If a parent is not given, it will automatically
  # inherit from the next highest tracer in the call stack, if any.
  #
  # The default set of tags includes a unique ID string, so all
  # log messages generated from that tracer will have the same
  # ID string. In combination with auto-inheriting from a parent
  # tracer, this means that all tracing messages starting from
  # some common root will have the same ID string to be able
  # to group together related messages in the log.
  def init_tracer(parent: nil, tags: nil)
    parent ||= Tracer.default_parent
    @tracer = Tracer.new(parent, tags: tags)
  end
end

require 'traceable/args'
require 'traceable/class_methods'
require 'traceable/config'
require 'traceable/tracer'
