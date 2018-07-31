# frozen_string_literal: true

RSpec.describe Traceable::Args do
  before do
    Traceable.configure do |config|
      config.max_string_length = 2000
      config.max_array_values = 10
      config.max_hash_keys = 10
    end
  end

  describe '#args_to_tags' do
    class Foo
      class << self
        def m1(a, b); end
      end
    end

    let(:m1_params) { Foo.method(:m1).parameters }

    it 'converts simple params' do
      expect(Traceable::Args.args_to_tags(m1_params, [1, 2]))
        .to eq(a: 1, b: 2)
    end

    it 'converts array params' do
      expect(Traceable::Args.args_to_tags(m1_params, [[1, 2], %i[a b c]]))
        .to eq(a: [1, 2], b: %i[a b c])
    end

    it 'converts hash params' do
      expect(Traceable::Args.args_to_tags(m1_params, [{ x: 1, y: 2 }, { 'z' => 3 }]))
        .to eq(a: { x: 1, y: 2 }, b: { 'z' => 3 })
    end
  end

  let(:letters) { %w[a b c d e f g h i j k l m n o p q r s t u v w x y z] }
  let(:long_string) { 'abcdefghijklmnopqrstuvwxyz'. * 100 }
  let(:long_string_truncated) { long_string[0..1997] + '...' }

  describe '#format_value' do
    let(:number) { 1 }

    it 'truncates long strings' do
      expect(Traceable::Args.format_value(long_string))
        .to eq(long_string_truncated)
    end

    it 'returns simple values un-modified' do
      expect(Traceable::Args.format_value(number)). to be number
      expect(Traceable::Args.format_value(nil)). to be nil
      expect(Traceable::Args.format_value(true)). to be true
      expect(Traceable::Args.format_value(false)). to be false
    end
  end

  describe '#format_array_of_values' do
    it 'truncates long arrays' do
      expect(Traceable::Args.format_array_of_values(letters))
        .to eq(%w[a b c d e f g h i ...(17)])
    end
  end

  describe '#format_hash_of_values' do
    it 'truncates long hashes' do
      h = Hash[letters.map { |l| [l.to_sym, l] }]
      expect(Traceable::Args.format_hash_of_values(h))
        .to eq(a: 'a', b: 'b', c: 'c', d: 'd', e: 'e',
               f: 'f', g: 'g', h: 'h', i: 'i', ___: '...(17)')
    end

    it 'truncates long strings in hashes' do
      expect(Traceable::Args.format_hash_of_values(foo: long_string))
        .to eq(foo: long_string_truncated)
    end
  end
end
