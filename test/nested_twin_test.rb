require "test_helper"
require "mini_twin"

class NestedTwin < MiniTwin
  property :sub_property, as: :renamed
  property :another_sub_property, default: "default"
  nested :nested do
    property :this_is_nested
  end
end

class NestedTwinTest < ActiveSupport::TestCase
  test "should handle nested twins" do
    twin = NestedTwin.new(sub_property: "test", this_is_nested: 'nested')
    result = twin.to_hash
    # Top-level alias is used and default property is present
    assert_equal "test", result[:renamed]
    assert_equal "default", result[:another_sub_property]
    # Nested proxy is grouped under :nested
    assert_equal "nested", result[:nested][:this_is_nested]
    # Proxy is not serialized at top-level
    assert_not result.key?(:this_is_nested)
  end
end

class DeepNestedTwin < MiniTwin
  nested :outer do
    property :a
    nested :inner do
      property :b
    end
  end
end

class DeepNestedTwinTest < ActiveSupport::TestCase
  test "should serialize nested structure in to_hash and to_json" do
    twin = DeepNestedTwin.new(a: "A", b: "B")

    h = twin.to_hash
    assert_equal "A", h[:outer][:a]
    assert_equal "B", h[:outer][:inner][:b]
    # Ensure top-level proxies are not serialized
    refute h.key?(:a)
    refute h.key?(:b)

    json = twin.to_json
    parsed = JSON.parse(json)
    assert_equal "A", parsed.dig("outer", "a")
    assert_equal "B", parsed.dig("outer", "inner", "b")
  end
end
