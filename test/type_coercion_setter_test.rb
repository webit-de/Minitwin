require "test_helper"

class TypeCoercionSetterTest < ActiveSupport::TestCase
  class CountingType
    attr_reader :calls
    def initialize
      @calls = 0
    end
    def call(v)
      @calls += 1
      Integer(v)
    end
  end

  CT = CountingType.new

  class T < Minitwin
    property :n, type: CT
  end

  test "setter stores coerced value" do
    CT.instance_variable_set(:@calls, 0)
    t = T.new
    t.n = "42"
    assert_equal 42, t.instance_variable_get(:@n)
  end

  test "getter does not re-coerce on each read" do
    CT.instance_variable_set(:@calls, 0)
    t = T.new(n: "1")
    before = CT.calls
    t.n; t.n; t.n
    assert_equal before, CT.calls, "expected no additional coercion on read"
  end

  test "constructor input is coerced" do
    t = T.new(n: "7")
    assert_equal 7, t.n
  end

  test "dry-types Integer still works" do
    klass = Class.new(Minitwin) do
      property :i, type: Types::Coercible::Integer
    end
    t = klass.new(i: "42")
    assert_equal 42, t.i
    assert_equal 42, t.instance_variable_get(:@i)
  end
end
