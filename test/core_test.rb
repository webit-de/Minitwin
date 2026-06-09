# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class CoreTest < ActiveSupport::TestCase
  test "should expose VERSION and DSL" do
    assert Minitwin::VERSION

    klass = Class.new(Minitwin) do
      property :id
      collection :items do
        property :name
      end
    end

    obj = klass.new(id: 1, items: [{ name: "a" }])
    assert_equal 1, obj.id
    assert_equal "a", obj.items.first.name
  end

  test "to_hash falls back when serializable_getters not available" do
    klass = Class.new(Minitwin) do
      property :a
    end
    # Hide serializable_getters to force else branch
    def klass.respond_to?(name, include_private = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
      return false if name == :serializable_getters && include_private

      super
    end
    twin = klass.new(a: 1)
    assert_equal({ a: 1 }.with_indifferent_access, twin.to_hash)
  end

  test "ordered_methods_for_pp else branch and inspect formatting" do
    klass = Class.new(Minitwin) do
      property :a
      property :b
    end
    def klass.respond_to?(name, include_private = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
      return false if name == :serializable_getters && include_private
      return false if name == :property_order && include_private

      super
    end
    twin = klass.new(a: 1, b: 2)
    attrs = twin.send(:ordered_attributes_for_pp)
    assert_includes attrs, [:a, 1]
    assert_includes attrs, [:b, 2]
    # inspect
    s = twin.inspect
    assert_includes s, "#<"
    assert_includes s, "a: 1"
    assert_includes s, "b: 2"
  end

  test "inherited hook tracks descendants of Minitwin subclasses" do
    # Create a direct subclass of Minitwin
    parent_klass = Class.new(Minitwin) do
      property :id
    end

    # Create a subclass of the subclass (not directly from Minitwin)
    child_klass = Class.new(parent_klass) do
      property :name
    end

    # Both should be tracked in Minitwin.__descendants__
    assert_includes(
      Minitwin.__descendants__,
      parent_klass,
      "Direct Minitwin subclass should be tracked"
    )
    assert_includes(
      Minitwin.__descendants__,
      child_klass,
      "Subclass of Minitwin subclass should also be tracked in Minitwin.__descendants__"
    )
  end

  test "allowed_attribute_keys includes inherited properties" do
    # Create a parent class with a property
    parent_klass = Class.new(Minitwin) do
      property :inherited_prop
    end

    # Create a child class that adds its own property
    child_klass = Class.new(parent_klass) do
      property :child_prop
    end

    # Child class should have both its own and inherited properties as allowed keys
    allowed_keys = child_klass.send(:allowed_attribute_keys)
    assert_includes(
      allowed_keys,
      :inherited_prop,
      "Inherited property should be in allowed_attribute_keys"
    )
    assert_includes(
      allowed_keys,
      :child_prop,
      "Child's own property should be in allowed_attribute_keys"
    )
  end

  test "initialize passes attributes as positional hash to ActiveModel" do
    # This test verifies that attributes are properly passed through
    # ActiveModel::API#initialize (which expects a positional hash, not kwargs)
    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    # Create instance with multiple attributes
    obj = klass.new(name: "test", value: 42)

    # Verify attributes were properly assigned via ActiveModel's assign_attributes
    assert_equal(
      "test",
      obj.name,
      "Attributes should be assigned via ActiveModel::API#initialize"
    )
    assert_equal(
      42,
      obj.value,
      "Multiple attributes should all be assigned correctly"
    )
  end

  test "allowed_attribute_keys_array preserves property definition order" do
    klass = Class.new(Minitwin) do
      property :charlie
      property :alpha
      property :bravo
    end

    assert_equal %i[charlie alpha bravo], klass.send(:allowed_attribute_keys_array)
  end

  test "allowed_attribute_keys_array appends inherited keys not in property_order at the end" do
    parent_klass = Class.new(Minitwin) do
      property :parent_prop
    end

    child_klass = Class.new(parent_klass) do
      property :child_prop
    end

    ordered = child_klass.send(:allowed_attribute_keys_array)
    child_index = ordered.index(:child_prop)
    parent_index = ordered.index(:parent_prop)

    assert child_index, "child_prop should be present"
    assert parent_index, "parent_prop should be present"
    assert_operator child_index, :<, parent_index, "child_prop (in property_order) should come before inherited parent_prop"
  end

  test "initialize uses private allowed_attribute_keys method" do
    # This test verifies that initialize correctly calls the private
    # allowed_attribute_keys method using respond_to?(name, true) and send()
    klass = Class.new(Minitwin) do
      property :name
      property :age
    end

    # Verify allowed_attribute_keys is private (not public)
    assert_not(
      klass.respond_to?(:allowed_attribute_keys),
      "allowed_attribute_keys should not be a public method"
    )
    assert klass.respond_to?(:allowed_attribute_keys, true), "allowed_attribute_keys should be accessible as a private method" # rubocop: disable Minitest/AssertRespondTo -- assertion helper has no parameter for `include_all`

    # Verify initialization works correctly despite the method being private
    obj = klass.new(name: "Alice", age: 30)
    assert_equal(
      "Alice",
      obj.name,
      "Private allowed_attribute_keys should be called during initialization"
    )
    assert_equal(
      30,
      obj.age,
      "All allowed attributes should be assigned correctly"
    )
  end
end
