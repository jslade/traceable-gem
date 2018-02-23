# frozen_string_literal: true

RSpec.describe Traceable do
  class FakeLogger
    attr_reader :logs
    def initialize
      @logs = []
    end

    %i[info debug warn error fatal].each do |method|
      define_method(method) do |tags|
        logs << { method: method, tags: tags }
      end
    end
  end

  let(:fake_logger) { FakeLogger.new }
  let(:logs) { fake_logger.logs }

  before do
    allow_any_instance_of(Traceable::Tracer).to receive(:logger) { fake_logger }
  end

  let(:subject_class) do
    Class.new do
      include Traceable

      attr_reader :non_traced_called
      def a_non_traced_method
        @non_traced_called = true
        :non_traced_return_value
      end

      attr_reader :traced_called
      traced_method def a_traced_method
        @traced_called = true
        yield if block_given?
        :traced_return_value
      end

      traced_method def a_traced_method_that_calls_a_block_with_a_parameter(val)
        yield val
      end

      def trace_as_a_block
        trace 'an example' do
          trace 'a nested block' do
            true
          end
        end
      end

      def self.a_class_method
        trace 'in a class method'
        trace 'in a class method with a block' do
          trace.info 'test'
        end
      end
    end
  end

  let(:contained_class) do
    Class.new do
      include Traceable

      def initialize(parent)
        init_tracer(parent: parent, tags: { inside: true })
      end
    end
  end

  subject do
    subject_class.new
  end

  describe '#configure' do
    it 'receives a Config instance' do
      @config = nil
      Traceable.configure { |c| @config = c }
      expect(@config).to be_a Traceable::Config
    end
  end

  describe '#config' do
  end

  describe '#trace' do
    it 'responds to #trace' do
      expect(subject.respond_to?(:trace)).to eq(true)
    end

    context 'when no block is given' do
      it 'can be used like an explicit logger' do
        subject.trace.info 'general info'
        subject.trace.warn 'a warning'
        subject.trace.error 'things look bad'
        subject.trace.fatal 'fell on the floor'
        subject.trace.debug 'fix me'
        expect(logs[0][:method]).to eq(:info)
        expect(logs[1][:method]).to eq(:warn)
        expect(logs[2][:method]).to eq(:error)
        expect(logs[3][:method]).to eq(:fatal)
        expect(logs[4][:method]).to eq(:debug)
      end

      it 'logs as info as default' do
        subject.trace 'blah', foo: :bar
        expect(logs.size).to be(1)
        expect(logs[0][:method]).to eq(:info)
        expect(logs[0][:tags][:foo]).to be(:bar)
      end
    end

    context 'when a block is given' do
      it 'logs at start and end of the block' do
        subject.trace_as_a_block
        expect(logs.size).to be(4)
        expect(logs[0][:tags].key?(:enter)).to be(true)
        expect(logs[0][:tags][:message]).to eq('START: an example')
        expect(logs[1][:tags].key?(:enter)).to be(true)
        expect(logs[1][:tags][:message]).to eq('START: a nested block')
        expect(logs[2][:tags].key?(:exit)).to be(true)
        expect(logs[2][:tags][:message]).to eq('END: a nested block')
        expect(logs[3][:tags].key?(:exit)).to be(true)
        expect(logs[3][:tags][:message]).to eq('END: an example')
      end

      it 'reports the elapsed time of the block' do
        subject.trace_as_a_block
        count = 0
        logs.select { |log| log[:tags].key?(:exit) }.each do |log|
          expect(log[:tags][:elapsed]).to be_a(Numeric)
          count += 1
        end
        expect(count).to be(2)
      end
    end

    context 'in a class method' do
      it 'works just like an instance method' do
        expect { subject.class.a_class_method }.to change { logs.size }.by 4
      end
    end
  end

  describe '#local_tracer' do
    it 'returns a Tracer object' do
      expect(subject.local_tracer).to be_a(Traceable::Tracer)
    end

    it 'inherits a parent tracer' do
      contained = contained_class.new(subject)
      expect(contained.local_tracer).not_to eq(subject.local_tracer)
      expect(contained.local_tracer.parent).to eq(subject.local_tracer)
    end

    it 'adds tags from the child' do
      contained = contained_class.new(subject)
      expect(subject.local_tracer.tags.key?(:inside)).to be(false)
      expect(contained.local_tracer.tags.key?(:inside)).to be(true)
    end

    context 'tracer IDs' do
      class Foo
        include Traceable
        def do_it
          trace 'outside' do
            trace 'inside' do
              trace 'a message'
            end
          end
        end
      end

      it 'creates a unique ID each time' do
        (1..10).each do |_|
          Foo.new.do_it
        end

        ids = Set.new
        logs.each { |log| ids << log[:tags][:trace] }
        expect(ids.size).to eq(10)
      end
    end
  end

  describe '.traced_method' do
    context 'for non-traced methods' do
      it 'does not interfere' do
        expect(subject.a_non_traced_method).to eq(:non_traced_return_value)
        expect(subject.non_traced_called).to eq(true)
      end
    end

    context 'for traced methods' do
      it 'does not interfere' do
        expect(subject.a_traced_method).to eq(:traced_return_value)
        expect(subject.traced_called).to eq(true)
      end

      it 'emits a log entry at start and end' do
        subject.a_traced_method
        expect(logs.size).to be(2)
        expect(logs[0][:tags].key?(:enter)).to be(true)
        expect(logs[1][:tags].key?(:exit)).to be(true)
      end

      it 'catches and raises exceptions' do
        expect { subject.a_traced_method { raise 'oops' } }.to raise_error('oops')
        expect(logs.size).to be(2)
        expect(logs[0][:tags].key?(:enter)).to be(true)
        expect(logs[1][:tags].key?(:exception)).to be(true)
        expect(logs[1][:tags].key?(:elapsed)).to be(true)
        expect(logs[1][:tags].key?(:backtrace)).to be(true)
      end

      it 'catches and raises exceptions through nested blocks' do
        expect do
          subject.trace 'level one' do
            subject.a_traced_method do
              subject.trace 'level two' do
                raise 'oops'
              end
            end
          end
        end.to raise_error('oops')

        origin = logs.find { |log| log[:tags][:exception] && log[:tags][:message].include?('level two') }
        expect(origin[:tags].key?(:backtrace)).to be(true)

        middle = logs.find { |log| log[:tags][:exception] && log[:tags][:message].include?('a_traced_method') }
        expect(middle[:tags].key?(:backtrace)).to be(false)
        expect(middle[:tags][:message].include?('propagated')).to be(true)

        outer = logs.find { |log| log[:tags][:exception] && log[:tags][:message].include?('level one') }
        expect(outer[:tags].key?(:backtrace)).to be(false)
        expect(middle[:tags][:message].include?('propagated')).to be(true)
      end

      it 'properly passes a block through' do
        yielded = false
        subject.a_traced_method do
          yielded = true
        end
        expect(yielded).to eq(true)
      end

      it 'properly passes a block with args through' do
        yielded = false
        subject.a_traced_method_that_calls_a_block_with_a_parameter(:blah) do |val|
          yielded = val
        end
        expect(yielded).to eq(:blah)
      end
    end
  end

  describe Traceable::Tracer do
    describe '#default_parent' do
      class One
        include Traceable
        def initialize
          init_tracer tags: { one: true }
        end

        traced_method def first
          Two.new.second
          Thread.new { Two.new.second }.join # New thread --> don't inherit tracer context
        end
      end

      class Two
        def second
          Three.new.third
        end
      end

      class Three
        include Traceable
        traced_method def third
          trace 'in the third', three: true
        end
      end

      it 'should include tags from the default parent' do
        One.new.first
        # expected logs:
        # 0 START: One#first, :one => true
        # 1   START: Three#third, :one => true, :three => true
        # 2     'in the third', :one => true, :three => true
        # 3   END: Three#third
        # 4   START: Three#third, :three => true
        # 5     'in the third', :three => true
        # 6   END: Three#third
        # 7 END: One#first, :one => true
        expect(logs.count).to be(8)

        expect(logs[1][:tags].key?(:one)).to be(true)
        expect(logs[2][:tags].key?(:one)).to be(true)
        expect(logs[1][:tags][:trace]).to eq(logs[0][:tags][:trace]) # Same parent, same trace tag

        expect(logs[4][:tags].key?(:one)).to be(false)
        expect(logs[5][:tags].key?(:one)).to be(false)
        expect(logs[4][:tags][:trace]).to_not eq(logs[1][:tags][:trace]) # Diff parent, diff trace tag
      end
    end

    describe '#initialize' do
      it 'complains with invalid argument' do
        expect { Traceable::Tracer.new('foo') }.to raise_error(ArgumentError)
      end
    end

    describe '#emit_tags' do
      context 'when logger chokes on the message' do
        before do
          allow(fake_logger).to receive(:info) { raise('blow chunks') }
        end
        it 'does not allow the exception to blow up' do
          t = Traceable::Tracer.new(nil)
          expect(t).to receive(:emit_tags).twice.and_call_original
          t.info(message: 'just a test')
        end
      end
    end
  end
end
