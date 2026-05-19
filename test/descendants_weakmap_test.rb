require "test_helper"

class DescendantsWeakMapTest < ActiveSupport::TestCase
  test "descendants registry is a WeakMap (no strong refs)" do
    map = Minitwin.instance_variable_get(:@__descendants_map__)
    assert_kind_of ObjectSpace::WeakMap, map
  end

  test "subclasses are registered in the descendants registry" do
    klass = Class.new(Minitwin) { property :x }
    assert_includes Minitwin.__descendants__, klass
  end

  class NamedTwin < Minitwin
    property :a
  end

  test "named subclasses remain in descendants" do
    GC.start
    assert_includes Minitwin.__descendants__, NamedTwin
  end
end
