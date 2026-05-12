require "test_helper"

class DescendantsWeakMapTest < ActiveSupport::TestCase
  test "descendants registry is a WeakMap (no strong refs)" do
    map = MiniTwin.instance_variable_get(:@__descendants_map__)
    assert_kind_of ObjectSpace::WeakMap, map
  end

  test "subclasses are registered in the descendants registry" do
    klass = Class.new(MiniTwin) { property :x }
    assert_includes MiniTwin.__descendants__, klass
  end

  class NamedTwin < MiniTwin
    property :a
  end

  test "named subclasses remain in descendants" do
    GC.start
    assert_includes MiniTwin.__descendants__, NamedTwin
  end
end
