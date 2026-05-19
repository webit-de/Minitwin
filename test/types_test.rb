require "test_helper"
require "mini_twin"

class TypesTest < ActiveSupport::TestCase
  test "type_default_value covers Integer, String, Bool branches" do
    helper = Class.new(Minitwin)
    int_t = Object.new
    def int_t.primitive; Integer; end
    def int_t.to_s; "Integer"; end
    str_t = Object.new
    def str_t.primitive; String; end
    def str_t.to_s; "String"; end
    bool_t = Object.new
    def bool_t.primitive; TrueClass; end
    def bool_t.to_s; "Bool"; end
    assert_equal 0, helper.send(:type_default_value, int_t)
    assert_equal "", helper.send(:type_default_value, str_t)
    assert_equal false, helper.send(:type_default_value, bool_t)
  end

  class WeirdType
    def to_s; "Weird Integer"; end
    def class; Struct; end
  end

  test "infer_default_from_type_string rescue path" do
    helper = Class.new(Minitwin)
    weird = WeirdType.new
    assert_equal 0, helper.send(:infer_default_from_type_string, weird)
  end
end
