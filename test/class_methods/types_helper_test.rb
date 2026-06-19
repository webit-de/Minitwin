# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class TypesHelperTest < ActiveSupport::TestCase
  # === type_default_value: primitive branches (white-box) ===

  test "type_default_value returns 0, empty string, false for Integer/String/Bool primitives" do
    twin_klass = Class.new(Minitwin)
    int_t = Object.new
    def int_t.primitive
      Integer
    end

    def int_t.to_s
      "Integer"
    end
    str_t = Object.new
    def str_t.primitive
      String
    end

    def str_t.to_s
      "String"
    end
    bool_t = Object.new
    def bool_t.primitive
      TrueClass
    end

    def bool_t.to_s
      "Bool"
    end
    assert_equal 0, twin_klass.send(:type_default_value, int_t)
    assert_equal "", twin_klass.send(:type_default_value, str_t)
    refute twin_klass.send(:type_default_value, bool_t)
  end

  # A fake type whose #class is overridden so type_description includes "Integer",
  # driving the infer_default_from_type_string fallback path.
  class WeirdType
    def to_s
      "Weird Integer"
    end

    def class
      Struct
    end
  end

  test "infer_default_from_type_string infers from string representation of fake type" do
    twin_klass = Class.new(Minitwin)
    weird = WeirdType.new
    assert_equal 0, twin_klass.send(:infer_default_from_type_string, weird)
  end

  test "infer_default_from_type_string rescues when to_s raises and returns nil" do
    helper = Class.new { extend Minitwin::ClassMethods }
    bomb = Object.new
    def bomb.to_s
      raise "boom"
    end
    # Should rescue and return nil
    assert_nil helper.send(:infer_default_from_type_string, bomb)
  end

  # === type defaults at getter level ===

  test "getter uses type_default_value for Integer and String types" do
    klass = Class.new(Minitwin) do
      property :i, type: Types::Integer
      property :s, type: Types::String
    end
    t = klass.new
    assert_equal 0, t.i
    assert_equal "", t.s
  end

  test "integer type defaults to 0" do
    klass = Class.new(Minitwin) do
      property :count, type: Types::Integer
    end

    obj = klass.new
    # Should default to 0 for integer types
    assert_equal 0, obj.count
  end

  test "string type defaults to empty string" do
    klass = Class.new(Minitwin) do
      property :text, type: Types::String
    end

    obj = klass.new
    # Should default to "" for string types
    assert_equal "", obj.text
  end

  test "boolean type defaults to false or nil" do
    # A custom boolean type that returns TrueClass as primitive
    bool_type = Types::Nominal::Bool

    klass = Class.new(Minitwin) do
      property :active, type: bool_type
    end

    obj = klass.new
    # For boolean-like types without explicit default, should return false or nil
    # The specific behavior depends on the type's primitive
    assert_includes [false, nil], obj.active
  end

  test "unknown type without default returns nil" do
    klass = Class.new(Minitwin) do
      # Use a custom type that doesn't match standard patterns
      custom_type = Types::Nominal::Any
      property :custom, type: custom_type, default: nil
    end

    obj = klass.new
    # Should return nil for unknown type without default
    assert_nil obj.custom
  end

  test "default inferred from type string representation for constructor type" do
    # Create a type without a clear primitive
    custom_int_type = Types.Constructor(Integer, &:to_i)

    klass = Class.new(Minitwin) do
      property :number, type: custom_int_type
    end

    obj = klass.new
    # Should infer Integer from type string
    assert_equal 0, obj.number
  end

  # === coerce_with_type / dry-types coercion at assignment ===

  test "type coercion errors keep the original value" do
    klass = Class.new(Minitwin) do
      property :age, type: Types::Strict::Integer
    end

    # Should not raise, but keep original value when coercion fails
    obj = klass.new(age: "invalid")
    assert_equal "invalid", obj.age
  end

  test "forces string conversion when dry-types coercion does not return a string" do
    klass = Class.new(Minitwin) do
      property :text, type: Types::Coercible::String
    end

    obj = klass.new(text: 123)
    assert_equal "123", obj.text
  end

  test "dry-types Coercible::Integer coerces and stores the coerced value" do
    klass = Class.new(Minitwin) do
      property :i, type: Types::Coercible::Integer
    end
    t = klass.new(i: "42")
    assert_equal 42, t.i
    assert_equal 42, t.instance_variable_get(:@i)
  end

  # === lambda types ===

  class LambdaTypeTwin < Minitwin
    property :count, type: ->(v) { Integer(v) }, default: 0
    property :label, type: ->(v) { v.to_s.strip }
  end

  test "lambda type coerces values" do
    twin = LambdaTypeTwin.from_hash(count: "42", label: "  hello  ")
    assert_equal 42, twin.count
    assert_equal "hello", twin.label
  end

  test "lambda type uses explicit default" do
    twin = LambdaTypeTwin.from_hash({})
    assert_equal 0, twin.count
  end

  # === custom callable type: coercion at setter vs. getter ===

  class CountingType
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def call(value)
      @calls += 1
      Integer(value)
    end
  end

  CT = CountingType.new

  class CountingTwin < Minitwin
    property :n, type: CT
  end

  test "setter stores coerced value" do
    CT.instance_variable_set(:@calls, 0)
    t = CountingTwin.new
    t.n = "42"
    assert_equal 42, t.instance_variable_get(:@n)
  end

  test "getter does not re-coerce on each read" do
    CT.instance_variable_set(:@calls, 0)
    t = CountingTwin.new(n: "1")
    before = CT.calls
    t.n
    t.n
    t.n
    assert_equal before, CT.calls, "expected no additional coercion on read"
  end

  test "constructor input is coerced" do
    t = CountingTwin.new(n: "7")
    assert_equal 7, t.n
  end
end
