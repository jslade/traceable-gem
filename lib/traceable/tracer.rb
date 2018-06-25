# frozen_string_literal: true

module Traceable
  # An instance of this class is used by each Traceable object to
  # generate log entries. Each log entry consists of a key/value
  # map ("tags"). Tags will be inherited from a parent instance,
  # if provided.

  # rubocop:disable Metrics/ClassLength
  class Tracer
    attr_accessor :logger
    attr_reader :parent
    attr_reader :tags

    def initialize(parent_tracer, tags: nil, logger: nil)
      @parent = which_parent(parent_tracer)
      @logger = logger || (@parent ? @parent.logger : Tracer.default_logger)
      @tags = @parent ? @parent.tags.dup : Tracer.default_tags
      @tags.merge!(tags) if tags
    end

    def self.default_logger
      Traceable.config.logger
    end

    def self.default_tags
      tags = Traceable.config.default_tags.merge(
        trace: SecureRandom.uuid
      )
      tags.each_key do |k|
        value = tags[k]
        tags[k] = value.call if value.respond_to?(:call)
      end
      tags
    end

    def emit(method, msg, **tags)
      final_tags = make_tags(message: msg, **tags)
      emit_tags(method, final_tags)
    end

    def make_tags(**tags)
      @tags.merge(tags)
    end

    def emit_tags(method, tags)
      logger.send(method, tags)
      nil
    rescue StandardError => ex
      warn "EXCEPTION in trace: #{ex}"
      nil
    end

    def fatal(msg, **tags)
      emit :fatal, msg, **tags
    end

    def error(msg, **tags)
      emit :error, msg, **tags
    end

    def warn(msg, **tags)
      emit :warn, msg, **tags
    end

    def info(msg, **tags)
      emit :info, msg, **tags
    end

    def debug(msg, **tags)
      emit :debug, msg, **tags
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def do_block(msg, **tags, &_)
      info "START: #{msg}", enter: true, **tags
      block_start_time = Time.now.utc

      begin
        push
        yield tags
      rescue StandardError => ex
        elapsed = Time.now.utc - block_start_time
        if ex.instance_variable_defined?(:@traceable_rescued)
          origin = ex.instance_variable_get(:@traceable_rescued)
          ex_message = " [propagated from #{origin}]"
        else
          ex.instance_variable_set(:@traceable_rescued, msg)
          ex_message = ", #{ex.message}"
          tags[:backtrace] ||= ex.backtrace.join('\n')
        end

        warn "EXCEPTION: #{msg} => #{ex.class.name}#{ex_message}",
             exception: true, elapsed: elapsed, class: ex.class.name, **tags

        raise
      ensure
        pop

        unless ex
          elapsed = Time.now.utc - block_start_time
          info "END: #{msg}", exit: true, elapsed: elapsed, **tags
        end
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def self.default_parent
      tracer_stack.last # nil if nothing currently on the stack
    end

    # The tracer stack is a thread-local list of tracer instances, allowing the
    # current tracer context to be automatically inherited by any other tracer
    # instances created further down in the stack.
    #
    # The current tracer is pushed onto the stack when entering a traced block,
    # then popped from the stack when leaving the traced block.

    def self.tracer_stack
      Thread.current[:tracer_stack] ||= []
    end

    private

    def which_parent(parent_tracer)
      case parent_tracer
      when nil
        nil
      when Tracer
        parent_tracer
      when Traceable
        parent_tracer.local_tracer
      else
        raise(ArgumentError, "#{parent_tracer} (#{parent_tracer.class})")
      end
    end

    def push
      Tracer.tracer_stack.push self
    end

    def pop
      Tracer.tracer_stack.pop
    end
  end
  # rubocop:enable Metrics/ClassLength
end
