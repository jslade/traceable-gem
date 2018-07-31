# frozen_string_literal: true

module Traceable
  class Args
    # parameters comes from calling method(:foo).parameters,
    # so it is an array of parameter descriptors e.g.
    # [ [:req, :a], [:keyreq, :b] ]
    # values is an array of values from an actual method invocation,
    # so the two arrays are expected to match in length
    def self.args_to_tags(parameters, values)
      tags = {}
      parameters.each_with_index do |param, i|
        tags[param[1]] = format_value(values[i])
      end
      tags
    end

    def self.format_value(val)
      return val.to_trace if val.respond_to? :to_trace
      return format_array_of_values(val) if val.is_a? Array
      return format_hash_of_values(val) if val.is_a? Hash
      return format_string(val) if val.is_a? String
      val
    end

    MAX_STRING_LENGTH = 5000
    MAX_ARRAY_VALUES = 30
    MAX_HASH_KEYS = 30

    @max_string_length = MAX_STRING_LENGTH
    @trunc_string_length = @max_string_length - 3
    @max_array_values = MAX_ARRAY_VALUES
    @max_hash_keys = MAX_HASH_KEYS

    def self.set_config_limits(max_string_length:, max_array_values:, max_hash_keys:)
      @max_string_length = max_string_length.nil? ? MAX_STRING_LENGTH : max_string_length
      @trunc_string_length = [@max_string_length, 4].max - 3
      @max_array_values = max_array_values.nil? ? MAX_ARRAY_VALUES : max_array_values
      @max_hash_keys = max_hash_keys.nil? ? MAX_HASH_KEYS : max_array_values
    end

    def self.format_string(val)
      return val[0..@trunc_string_length] + '...' if val.size > @max_string_length
      val
    end

    def self.format_array_of_values(val_array)
      return format_array_of_values(truncated_array(val_array)) \
        if val_array.size > @max_array_values
      val_array.map { |v| format_value(v) }
    end

    def self.truncated_array(val_array)
      subset = val_array[0..@max_array_values - 2]
      subset << "...(#{val_array.size - subset.size})"
      subset
    end

    def self.format_hash_of_values(val_hash)
      return format_hash_of_values(truncated_hash(val_hash)) \
        if val_hash.size > @max_hash_keys
      Hash[val_hash.map { |k, v| [k, format_value(v)] }]
    end

    def self.truncated_hash(val_hash)
      first_keys = val_hash.keys[0..@max_hash_keys - 2]
      first_vals = first_keys.map { |k| val_hash[k] }
      first_keys << :___
      first_vals << "...(#{val_hash.size - first_vals.size})"
      Hash[first_keys.zip(first_vals)]
    end
  end
end
