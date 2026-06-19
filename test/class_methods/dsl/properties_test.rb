# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class DslPropertiesTest < ActiveSupport::TestCase
  ProcessCharsToThree = ->(value) { value[..3] }

  class GetterSetterTwin < Minitwin
    property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
    property :runtime_greater_than_three, getter: -> { runtime > 3 }
    property :set_days_with_variable_offset, setter: ->(value) { value.days.from_now.to_date }
    property :modify_me, getter: -> { "#{@modify_me} modified" }
    property :modified_symbol, getter: :modify_by_symbol

    private

    def modify_by_symbol
      "#{@modified_symbol} symbol"
    end
  end

  class SetterTwin < Minitwin
    property :name, setter: lambda(&:upcase)
    property :age, as: :settered_age, setter: ->(value) { value + 1 }
    property :nested do
      property :street, setter: lambda(&:upcase)
    end
    property :chars, setter: ProcessCharsToThree, type: Types::Coercible::String
  end

  class GetterWithArgTwin < Minitwin
    property :shout, getter: ->(val) { val&.upcase }
    property :code,  getter: :strip_dashes

    private

    def strip_dashes(val)
      val&.delete("-")
    end
  end

  class CallableDefaultTwin < Minitwin
    property :created_at, default: -> { Time.now }
    property :static_value, default: "hello"
  end

  # --- getter / setter behavior ---

  test "computes getter on instance" do
    a = GetterSetterTwin.from_hash(wrong_runtime: 3)
    b = GetterSetterTwin.from_hash(wrong_runtime: 4, modify_me: "I am")
    assert_not a.runtime_greater_than_three
    assert b.runtime_greater_than_three
    assert_equal "I am modified", b.modify_me
  end

  test "applies setter on instance" do
    a = GetterSetterTwin.new(set_days_with_variable_offset: 1)
    b = GetterSetterTwin.new(set_days_with_variable_offset: 2)
    assert_equal Date.tomorrow, a.set_days_with_variable_offset
    assert_equal 2.days.from_now.to_date, b.set_days_with_variable_offset
  end

  test "setter is applied to property" do
    obj = SetterTwin.new(name: "john", age: 25)
    assert_equal "JOHN", obj.name
  end

  test "setter is applied to aliased property" do
    obj = SetterTwin.new(name: "john", age: 25)
    assert_equal 26, obj.settered_age
  end

  test "setter is applied to nested property" do
    obj = SetterTwin.new(name: "john", age: 25, nested: { street: "main" })
    assert_equal "MAIN", obj.nested.street
  end

  test "setter is applied to coercible type" do
    obj = SetterTwin.new(chars: "abc")
    assert_equal "abc", obj.chars
    obj = SetterTwin.new
    assert_equal "", obj.chars
  end

  test "setter is applied in to_hash" do
    obj = SetterTwin.new(name: "john")
    assert_equal "JOHN", obj.to_hash[:name]
  end

  test "setter is applied in from_hash" do
    obj = SetterTwin.from_hash(name: "john")
    assert_equal "JOHN", obj.name
  end

  test "getter from symbol calls named method in instance context" do
    t = GetterSetterTwin.new(modified_symbol: "hello")
    assert_equal "hello symbol", t.modified_symbol
  end

  test "getter lambda with argument receives current property value" do
    t = GetterWithArgTwin.new(shout: "alice")
    assert_equal "ALICE", t.shout
  end

  test "getter symbol with argument receives current property value" do
    t = GetterWithArgTwin.new(code: "A-1-2")
    assert_equal "A12", t.code
  end

  # --- callable defaults ---

  test "callable default is evaluated on each access, not once at definition time" do
    counter = 0
    counting_default = -> { counter += 1 }

    klass = Class.new(Minitwin) do
      property :sequence, default: counting_default
    end

    twin = klass.new
    first = twin.sequence
    second = twin.sequence
    third = twin.sequence

    assert_equal 1, first
    assert_equal 2, second
    assert_equal 3, third
    assert_operator second, :>, first, "Expected an increasing value but the default was evaluated only once"
    assert_operator third, :>, second, "Expected an increasing value but the default was evaluated only once"
  end

  test "static defaults still work normally" do
    twin = CallableDefaultTwin.new
    assert_equal "hello", twin.static_value
  end

  test "callable default is not returned when value is explicitly set" do
    twin = CallableDefaultTwin.from_hash(created_at: Time.new(2020, 1, 1))
    assert_equal Time.new(2020, 1, 1), twin.created_at
  end

  # --- property getter / setter procs (edge cases) ---

  test "property getter with custom getter proc" do
    klass = Class.new(Minitwin) do
      property :computed, getter: -> { "computed_value" }
    end

    obj = klass.new
    assert_equal "computed_value", obj.computed
  end

  test "property setter with custom setter proc" do
    klass = Class.new(Minitwin) do
      property :upcased, setter: ->(v) { v.to_s.upcase }
    end

    obj = klass.new(upcased: "hello")
    assert_equal "HELLO", obj.upcased
  end

  test "raises when setter provided with block property" do
    # Need to instantiate to trigger the setter logic check
    klass = Class.new(Minitwin) do
      begin
        property :invalid, setter: ->(v) { v } do
          property :name
        end
      rescue StandardError => exception
        @caught_error = exception
      end

      class << self
        attr_reader :caught_error
      end
    end

    # The error should be caught during class definition
    assert_match(/setters are not possible in blocks/, klass.caught_error.message)
  end

  # --- defaults / types / boolean names (error handling) ---

  test "property without type returns nil" do
    klass = Class.new(Minitwin) do
      property :optional
    end

    obj = klass.new
    assert_nil obj.optional
  end

  test "property with explicit default taking precedence" do
    klass = Class.new(Minitwin) do
      property :count, type: Types::Integer, default: 42
    end

    obj = klass.new
    # Explicit default should take precedence over type default
    assert_equal 42, obj.count
  end

  test "boolean property with question mark" do
    klass = Class.new(Minitwin) do
      property :active?
    end

    # Should be able to create twins with question mark properties
    assert_nothing_raised do
      obj = klass.new
      obj.active? # Should not raise
    end
  end
end
