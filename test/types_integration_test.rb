require "test_helper"
require "mini_twin"

class TypesIntegrationTest < ActiveSupport::TestCase
  test "getter uses type_default_value for Integer/String/Bool" do
    klass = Class.new(MiniTwin) do
      property :i, type: MiniTwin::Types::Integer
      property :s, type: MiniTwin::Types::String
    end
    t = klass.new
    assert_equal 0, t.i
    assert_equal "", t.s
  end

  test "infer_default_from_type_string method-level rescue executes" do
    helper = Class.new { extend MiniTwin::ClassMethods }
    bomb = Object.new
    def bomb.to_s; raise "boom"; end
    # Should rescue and return nil
    assert_nil helper.send(:infer_default_from_type_string, bomb)
  end
end
