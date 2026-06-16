# frozen_string_literal: true

require "test_helper"
require "mini_twin"

# Exercises the rule that only *declared* properties/collections serialize:
# plain getters hand-defined on a twin are excluded, while `as:` aliases still
# serialize because #original_name maps the aliased reader back to its declared
# base property.
class DeclaredPropertyTwin < Minitwin
  property :name
  property :secret_value, as: :public_value, default: 10

  # A plain getter defined directly on the twin. It is *not* a declared
  # property, so it must be excluded from serialization even though it is a
  # public, argument-less method owned by this class.
  def computed
    "computed-#{name}"
  end
end

class DeclaredPropertySerializationTest < ActiveSupport::TestCase
  test "only declared properties serialize; plain getters are excluded" do
    obj = DeclaredPropertyTwin.from_hash(name: "x")

    hash = obj.to_hash

    assert_equal "x", hash[:name], "declared property must serialize"
    assert_equal 10, hash[:public_value], "as: alias must serialize under its alias name"
    assert_not hash.key?(:secret_value), "aliased original name must not serialize"
    assert_not hash.key?(:computed), "plain getter defined on twin must not serialize"
  end

  test "plain getter remains callable even though it does not serialize" do
    obj = DeclaredPropertyTwin.from_hash(name: "x")

    assert_equal "computed-x", obj.computed, "excluding from serialization must not undefine the method"
  end
end
