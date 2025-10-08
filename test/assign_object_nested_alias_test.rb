require "test_helper"
require "mini_twin"

class AssignNestedTwin < MiniTwin
  nested :nested do
    property :rename_me, as: :nested_renamed
    property :plain
  end
end

class AssignObjectNestedAliasTest < ActiveSupport::TestCase
  test "assign_object populates nested alias via base setter" do
    model = Data.define(:rename_me, :plain).new(rename_me: "omg", plain: "p")
    twin = AssignNestedTwin.new
    twin.assign_object(model)

    # alias getter exposed at top-level via nested proxy
    assert_equal "omg", twin.nested_renamed
    # plain nested property also proxied
    assert_equal "p", twin.plain

    # to_hash groups under :nested with aliased key
    expected = { nested: { nested_renamed: "omg", plain: "p" } }
    assert_equal expected.deep_stringify_keys, twin.to_hash
  end
end

