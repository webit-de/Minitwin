require "test_helper"
require "mini_twin"

class TypesIntegrationTest < ActiveSupport::TestCase
  test "getter uses type_default_value for Integer/String/Bool" do
    klass = Class.new(Minitwin) do
      property :i, type: Types::Integer
      property :s, type: Types::String
    end
    t = klass.new
    assert_equal 0, t.i
    assert_equal "", t.s
  end

  test "infer_default_from_type_string method-level rescue executes" do
    helper = Class.new { extend Minitwin::ClassMethods }
    bomb = Object.new
    def bomb.to_s; raise "boom"; end
    # Should rescue and return nil
    assert_nil helper.send(:infer_default_from_type_string, bomb)
  end
end

class LambdaTypeTwin < Minitwin
  property :count, type: ->(v) { Integer(v) }, default: 0
  property :label, type: ->(v) { v.to_s.strip }
end

class LambdaTypeTest < ActiveSupport::TestCase
  test "lambda type coerces values" do
    twin = LambdaTypeTwin.from_hash(count: "42", label: "  hello  ")
    assert_equal 42, twin.count
    assert_equal "hello", twin.label
  end

  test "lambda type uses explicit default" do
    twin = LambdaTypeTwin.from_hash({})
    assert_equal 0, twin.count
  end
end
