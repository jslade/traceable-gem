# frozen_string_literal: true

module Traceable
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Put an automatic '#trace' call around the specified method,
    # so that entry and exit from the method will be automatically logged.
    #
    # Can be used when defining the method:
    #
    #     class X
    #       include SISApp::Traceable
    #       traced_method def foo
    #         ...
    #       end
    #     end
    #
    # or it can be called after defining the method:
    #
    #    class X
    #      include SISApp::Traceable
    #      def foo
    #        ...
    #      end
    #      traced_method :foo
    #     end
    #
    # The generated log message(s) will include the class name and method name
    def traced_method(method_name, include_args: true)
      trace_name = "#{name}##{method_name}"
      orig_method = instance_method(method_name)
      params = orig_method.parameters
      include_args = false if params.empty?

      send(:define_method, method_name) do |*args, &block|
        trace_tags = include_args ? Traceable::Args.args_to_tags(params, args) : {}
        trace(trace_name, **trace_tags) do
          if block
            orig_method.bind(self).call(*args) { |*block_args| block.call(*block_args) }
          else
            orig_method.bind(self).call(*args)
          end
        end
      end

      method_name
    end

    # For the (relatively rare?) case of calling trace() in a class method
    # of a Traceable class - creates a new Tracer instance
    def trace(msg = nil, **tags)
      tracer = Tracer.new(Tracer.default_parent)

      if block_given?
        tracer.do_block(msg, **tags) { yield }
      elsif msg
        tracer.info msg, **tags
      else
        tracer
      end
    end
  end
end
