# frozen_string_literal: true

require "test_helper"
require "minitwin"

class CachesTest < ActiveSupport::TestCase
  # --- serializable getters: only declared properties serialize ---

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

  # Module providing a public instance method that requires arguments.
  # Mimics helpers like ActionView::Helpers::UrlHelper#sms_to which are mixed
  # into twins but must not be treated as serializable getters.
  module MixinWithArgMethod
    def needs_args(mandatory, optional_one = nil, optional_two = nil)
      [mandatory, optional_one, optional_two]
    end

    # Mixed-in setter, mimics helpers like ActionView's #output_buffer=.
    # Must not be treated as an assignable attribute. Raises if invoked so a
    # test can detect from_hash wrongly calling it.
    def mixin_setter=(_value)
      raise "mixed-in setter must not be invoked by from_hash"
    end
  end

  class MixinTwin < Minitwin
    include MixinWithArgMethod

    property :name

    # Plain getter defined directly on the twin must not be serialized; only
    # declared properties are.
    def computed
      "computed-#{name}"
    end
  end

  test "only declared properties serialize and plain getters are excluded" do
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

  test "mixed-in module methods are not serialized" do
    obj = MixinTwin.from_hash(name: "x")

    hash = obj.to_hash

    assert_not hash.key?(:needs_args), "mixed-in method should not be serialized"
    assert_not hash.key?(:computed), "plain getter defined on twin must not be serialized"
    assert_equal "x", hash[:name]
  end

  test "mixed-in module setters are not assignable attributes" do
    obj = nil

    assert_nothing_raised do
      obj = MixinTwin.from_hash(name: "x", mixin_setter: "boom")
    end

    assert_equal "x", obj.to_hash[:name]
  end

  test "serializable_getters cache is invalidated and rebuilt when a property is added" do
    klass = Class.new(Minitwin) do
      property :first
    end

    # Cache should be built
    klass.send(:serializable_getters)

    # Add another property
    klass.class_eval do
      property :second
    end

    # Cache should be invalidated and rebuilt
    second_getters = klass.send(:serializable_getters)
    assert_includes second_getters, :second
  end

  # --- dynamic aliases predicate ---

  class NoAliasesTwin < Minitwin
    property :name
    property :age
  end

  class WithDynamicAliasTwin < Minitwin
    property :name, as: -> { "n_#{age}" }
    property :age
  end

  test "class without dynamic aliases reports dynamic_aliases? false" do
    refute_predicate NoAliasesTwin, :dynamic_aliases?
  end

  test "class with dynamic alias reports dynamic_aliases? true" do
    assert_predicate WithDynamicAliasTwin, :dynamic_aliases?
  end

  # --- allowed attribute keys (inherited + ordering) ---

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

  # --- setter methods cache ---

  test "setter_methods cache lists every declared property writer" do
    klass = Class.new(Minitwin) do
      property :a
      property :b
    end
    setters = klass.send(:setter_methods)
    assert_includes setters, :a=
    assert_includes setters, :b=
  end
end
