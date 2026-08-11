# frozen_string_literal: true

require "test_helper"
require "minitwin"

class ErrorsTest < ActiveSupport::TestCase
  test "Minitwin::Error is a module, not a class" do
    assert_kind_of Module, Minitwin::Error
    refute_kind_of Class, Minitwin::Error
  end

  ERROR_CLASSES = {
    Minitwin::DefinitionError => ::ArgumentError,
    Minitwin::CompositionError => ::RuntimeError,
    Minitwin::AliasError => ::ArgumentError,
    Minitwin::CoercionError => ::TypeError,
    Minitwin::ParseError => ::ArgumentError
  }.freeze

  ERROR_CLASSES.each do |klass, base_class|
    test "#{klass} is catchable via Minitwin::Error and via #{base_class}" do
      caught_via_marker = begin
        raise klass, "boom"
      rescue Minitwin::Error
        true
      end
      assert caught_via_marker

      caught_via_base = begin
        raise klass, "boom"
      rescue base_class
        true
      end
      assert caught_via_base
    end
  end

  test "from_json wraps JSON::ParserError as Minitwin::ParseError and preserves #cause" do
    klass = Class.new(Minitwin) do
      property :name
    end

    error = assert_raises(Minitwin::ParseError) { klass.from_json("{not valid json") }
    assert_kind_of ::JSON::ParserError, error.cause
  end

  test "attempt_type_coercion re-raises a Minitwin::Error instead of swallowing it" do
    raising_type = Object.new
    def raising_type.call(_value)
      raise Minitwin::CoercionError, "boom"
    end

    klass = Class.new(Minitwin)

    assert_raises(Minitwin::CoercionError) do
      klass.send(:attempt_type_coercion, "x", raising_type)
    end
  end
end
