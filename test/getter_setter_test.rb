# frozen_string_literal: true

require "test_helper"
require "mini_twin"

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

CharsSetThree = ->(value) { value[..3] }

class SetMe < Minitwin
  property :name, setter: lambda(&:upcase)
  property :age, as: :settered_age, setter: ->(value) { value + 1 }
  property :nested do
    property :street, setter: lambda(&:upcase)
  end
  property :chars, setter: CharsSetThree, type: Types::Coercible::String
end

class GetterWithArgTwin < Minitwin
  property :shout, getter: ->(val) { val&.upcase }
  property :code,  getter: :strip_dashes

  private

  def strip_dashes(val)
    val&.delete("-")
  end
end

class GetterSetterTest < ActiveSupport::TestCase
  test "should compute getter on instance" do
    a = GetterSetterTwin.from_hash(wrong_runtime: 3)
    b = GetterSetterTwin.from_hash(wrong_runtime: 4, modify_me: "I am")
    assert_not a.runtime_greater_than_three
    assert b.runtime_greater_than_three
    assert_equal "I am modified", b.modify_me
  end

  test "should apply setter on instance" do
    a = GetterSetterTwin.new(set_days_with_variable_offset: 1)
    b = GetterSetterTwin.new(set_days_with_variable_offset: 2)
    assert_equal Date.tomorrow, a.set_days_with_variable_offset
    assert_equal 2.days.from_now.to_date, b.set_days_with_variable_offset
  end

  test "setter is applied to property" do
    obj = SetMe.new(name: "john", age: 25)
    assert_equal "JOHN", obj.name
  end

  test "setter is applied to aliased property" do
    obj = SetMe.new(name: "john", age: 25)
    assert_equal 26, obj.settered_age
  end

  test "setter is applied to nested property" do
    obj = SetMe.new(name: "john", age: 25, nested: { street: "main" })
    assert_equal "MAIN", obj.nested.street
  end

  test "setter is applied to coercible type" do
    obj = SetMe.new(chars: "abc")
    assert_equal "abc", obj.chars
    obj = SetMe.new
    assert_equal "", obj.chars
  end

  test "setter is applied in to_hash" do
    obj = SetMe.new(name: "john")
    assert_equal "JOHN", obj.to_hash[:name]
  end

  test "setter is applied in from_hash" do
    obj = SetMe.from_hash(name: "john")
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
end
