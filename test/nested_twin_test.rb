# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class NestedTwinTest < ActiveSupport::TestCase

  class NestedTwin < Minitwin
    property :sub_property, as: :renamed
    property :another_sub_property, default: "default"
    nested :nested do
      property :this_is_nested
      property :rename_me, as: :nested_renamed
    end
  end

  test "nested const lookup rescue path executes" do
    klass = Class.new(Minitwin) do
      nested :group do
        property :a
      end
    end
    t = klass.new
    t.group = { a: 1 }
    assert_equal 1, t.group.a
  end

  test "should handle nested twins" do
    twin = NestedTwin.new(sub_property: "test", this_is_nested: "nested", rename_me: "omg")
    result = twin.to_hash
    # Top-level alias is used and default property is present
    assert_equal "test", result[:renamed]
    assert_equal "default", result[:another_sub_property]
    # Nested proxy is grouped under :nested
    assert_equal "nested", result[:nested][:this_is_nested]
    assert_equal "omg", result[:nested][:nested_renamed]
    # Proxy is not serialized at top-level
    assert_not result.key?(:this_is_nested)
  end

  test "should handle nested twins from objects" do
    obj = Data.define(:rename_me).new(rename_me: "omg")
    twin = NestedTwin.from_object(obj)
    assert_raises(NoMethodError) { twin.rename_me }
    assert_equal({ another_sub_property: "default", nested: { nested_renamed: "omg" } }.deep_stringify_keys, twin.to_hash)
    assert_equal "omg", twin.nested_renamed
  end
end

class DeepNestedTwinTest < ActiveSupport::TestCase

  class DeepNestedTwin < Minitwin
    nested :outer do
      property :a
      nested :inner do
        property :b
        property :c, as: :d
      end
    end
  end

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

    h = DeepNestedTwin.new.to_hash
    assert_equal({ outer: { inner: {} } }.deep_stringify_keys, h)
  end
end

class NestedAsAliasTwinTest < ActiveSupport::TestCase

  class NestedAsAliasTwin < Minitwin
    nested :voranfrage_online_request, as: :"@vao:VoranfrageOnlineRequest" do
      property :kunde
      property :menge
    end
  end

  test "nested supports as: to rename the container key" do
    twin = NestedAsAliasTwin.new(kunde: "ACME", menge: 5)

    h = twin.to_hash
    # Container serialized under the aliased (otherwise-invalid) key
    assert_equal "ACME", h[:"@vao:VoranfrageOnlineRequest"][:kunde]
    assert_equal 5, h[:"@vao:VoranfrageOnlineRequest"][:menge]
    # Internal valid name is not exposed
    refute h.key?(:voranfrage_online_request)

    parsed = JSON.parse(twin.to_json)
    assert_equal "ACME", parsed.dig("@vao:VoranfrageOnlineRequest", "kunde")
  end

  test "nested with as: still hoists leaf readers and setters" do
    twin = NestedAsAliasTwin.new
    twin.kunde = "BETA"
    twin.menge = 9
    assert_equal "BETA", twin.kunde
    assert_equal 9, twin.menge
  end
end

class StringNamedNestedTwinTest < ActiveSupport::TestCase

  # A nested block can be declared with a String name (e.g. nested 'GF06'),
  # commonly used when the container key must match an external schema verbatim.
  class StringNamedNestedTwin < Minitwin
    nested :outer do
      nested "GROUP" do
        property :leaf
      end
    end
  end

  test "string-named nested block is seeded on flat init so leaf setters work" do
    twin = StringNamedNestedTwin.new(leaf: "value")

    assert_equal "value", twin.to_hash[:outer]["GROUP"][:leaf]
  end

  test "string-named nested block is seeded via from_hash with flat keys" do
    twin = StringNamedNestedTwin.from_hash(leaf: "value")

    assert_equal "value", twin.to_hash[:outer]["GROUP"][:leaf]
  end

  test "empty string-named nested block still serializes its container" do
    h = StringNamedNestedTwin.new.to_hash

    assert_equal({ outer: { "GROUP" => {} } }.deep_stringify_keys, h)
  end
end

class StringAliasNestedTwinTest < ActiveSupport::TestCase
  # Leaves whose `as:` alias is a String must be hidden from the parent's
  # serialization just like Symbol aliases are; otherwise the hoisted top-level
  # read proxy leaks a duplicate key at every ancestor level.
  class StringAliasNestedTwin < Minitwin
    nested :outer, as: "Outer" do
      property :name, as: "Name"
      nested :inner, as: "Inner" do
        property :code, as: "Code"
      end
    end
  end

  test "string-aliased leaves do not leak into ancestor serialization" do
    h = StringAliasNestedTwin.new(name: "n", code: "c").to_hash

    # Only the container key at the top level, nested structure underneath.
    assert_equal({ "Outer" => { "Name" => "n", "Inner" => { "Code" => "c" } } }.deep_stringify_keys, h)
  end

  test "string-aliased leaves stay writable at the top level (flat input)" do
    twin = StringAliasNestedTwin.new
    twin.name = "n"
    twin.code = "c"

    assert_equal "n", twin.to_hash["Outer"]["Name"]
    assert_equal "c", twin.to_hash["Outer"]["Inner"]["Code"]
  end
end
