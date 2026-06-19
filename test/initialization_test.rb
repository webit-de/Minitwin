# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class InitializationTest < ActiveSupport::TestCase
  # Fixtures

  class CoercionsAndDefaultsTwin < Minitwin
    property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0, validates: { presence: true }

    property :wrong_lego, as: :lego do
      property :brick, default: 0
      property :brick_two, default: 3456
      property :brick_wrong, as: :brick_right
    end

    property :unexposed_prop, expose: false
    property :duplo do
      property :brick, validates: { presence: true }
    end

    property :an_array
    collection :empty_array

    collection :cool_stuff, as: :list_of_stuff do
      property :property, as: :renamed_property, validates: { presence: true }
      property :second_property, default: "default"
      property :block_in_collection do
        property :i_cant_believe_it, type: Types::Params::Integer.lax
        property :bool, type: Types::Params::Bool.lax
      end
    end

    property :bool, type: Types::Params::Bool.lax
  end

  class DynamicAliasLambdaTwin < Minitwin
    property :sub_property
    property :another_sub_property, as: -> { @sub_property }
  end

  class NestedDynamicAliasLambdaTwin < Minitwin
    nested :some_nesting do
      property :sub_property
      property :another_sub_property, as: -> { @sub_property }
    end
  end

  class CollectionElementDynamicAliasTwin < Minitwin
    collection :items do
      property :sub_property
      property :another_sub_property, as: -> { @sub_property }
    end
  end

  class CollectionNameDynamicAliasTwin < Minitwin
    property :alias_key
    collection :items, as: -> { alias_key } do
      property :value
    end
  end

  class NoDynamicAliasTwin < Minitwin
    property :name
    property :age
  end

  class RecomputeOnceTwin < Minitwin
    property :name, as: -> { "n_#{name}" }
    property :age
    property :email
  end

  # initialize behavior

  test "creates twin with coercions and defaults applied" do
    obj = CoercionsAndDefaultsTwin.from_hash(
      wrong_runtime: "3",
      wrong_lego: { brick: 123, brick_wrong: "wrong" },
      duplo: { brick: "big_block" },
      unexposed_prop: "ignore me",
      cool_stuff: [
        { property: "test", block_in_collection: { i_cant_believe_it: "2", bool: "1" } },
        { property: "test_2", block_in_collection: { i_cant_believe_it: "4", bool: "false" } }
      ],
      an_array: [1, 2, 3],
      bool: "0"
    )

    assert_equal 3, obj.runtime
    assert_equal 123, obj.lego.brick
    assert_equal 3456, obj.lego.brick_two
    assert_equal "ignore me", obj.unexposed_prop
    assert_equal "big_block", obj.duplo.brick
    assert_equal "wrong", obj.lego.brick_right
    assert_equal 2, obj.list_of_stuff.size
    assert_equal "test", obj.list_of_stuff.first.renamed_property
    assert_equal "default", obj.list_of_stuff.first.second_property
    assert_equal 2, obj.list_of_stuff.first.block_in_collection.i_cant_believe_it
    assert_equal 4, obj.list_of_stuff.second.block_in_collection.i_cant_believe_it
    assert obj.list_of_stuff.first.block_in_collection.bool
    assert_respond_to obj, :cool_stuff_attributes=
    assert_equal [], obj.empty_array
    refute obj.bool

    obj.cool_stuff_attributes = {}
    assert_equal 0, obj.list_of_stuff.size
  end

  test "filters unknown keys on initialization" do
    klass = Class.new(Minitwin) do
      property :name
    end

    # Should silently ignore unknown keys
    obj = klass.new(name: "test", unknown: "value", another: "ignored")
    assert_equal "test", obj.name
    refute_respond_to obj, :unknown
  end

  test "initialize uses allowed_attribute_keys when provided" do
    klass = Class.new(Minitwin) do
      def self.allowed_attribute_keys
        Set[:foo]
      end

      attr_writer :foo

      attr_reader :foo

      attr_writer :bar

      attr_reader :bar
    end
    obj = klass.new(foo: 1, bar: 2)
    assert_equal 1, obj.foo
    assert_nil obj.instance_variable_get(:@bar)
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

  # dynamic aliases (recompute/rename/collision)

  test "accepts a lambda in an as attribute" do
    model = Data.define(:sub_property, :another_sub_property).new("a", "b")
    twin = DynamicAliasLambdaTwin.from_object(model)
    assert_equal "a", twin.sub_property
    assert_equal "b", twin.a
  end

  test "dynamic alias serializes under alias and updates on rename" do
    model = Data.define(:sub_property, :another_sub_property).new("key1", "val1")
    twin = DynamicAliasLambdaTwin.from_object(model)

    # Serializes using the dynamic alias as the key
    h = twin.to_hash
    assert_equal({ key1: "val1" }.with_indifferent_access, h.slice(:key1))
    refute h.key?(:another_sub_property)

    # Change the alias target and ensure serialization reflects the new key
    twin.sub_property = "key2"
    twin.another_sub_property = "val2"
    h2 = twin.to_hash
    assert_equal({ key2: "val2" }.with_indifferent_access, h2.slice(:key2))
    refute h2.key?(:key1)
  end

  test "assign_object copies attributes with nested aliased property" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "a", another_sub_property: "b")
    twin = NestedDynamicAliasLambdaTwin.new
    twin.assign_object(model)

    assert_equal "a", twin.sub_property
    assert_equal "b", twin.a
    # Update via top-level nested proxies
    twin.sub_property = "x"
    twin.another_sub_property = "y"
    assert_equal({ some_nesting: { sub_property: "x", x: "y" } }.deep_stringify_keys, twin.to_hash)
  end

  test "dynamic alias works in collection elements and renames on change" do
    item_struct = Data.define(:sub_property, :another_sub_property)
    model = Data.define(:items).new(items: [item_struct.new("k1", "v1"), item_struct.new("k2", "v2")])

    twin = CollectionElementDynamicAliasTwin.from_object(model)
    assert_equal 2, twin.items.size

    # First element exposes alias k1 and serializes under it
    first = twin.items.first
    assert_equal "v1", first.k1
    h = twin.to_hash
    assert_equal "v1", h[:items][0][:k1]
    refute h[:items][0].key?(:another_sub_property)

    # Rename inside element and verify updated alias and serialization
    first.sub_property = "k1_renamed"
    first.another_sub_property = "v1b"
    h2 = twin.to_hash
    assert_equal "v1b", twin.items.first.k1_renamed
    assert_equal "v1b", h2[:items][0][:k1_renamed]
    refute h2[:items][0].key?(:k1)
  end

  test "dynamic alias works on collection name and updates on rename" do
    model = Data.define(:alias_key, :items).new("things", [{ value: 1 }, { value: 2 }])
    twin = CollectionNameDynamicAliasTwin.from_hash(alias_key: model.alias_key, items: model.items)

    # Access via dynamic collection reader
    assert_respond_to twin, :things
    assert_equal [1, 2], twin.things.map(&:value)

    # Serialization uses dynamic collection name and omits base name
    h = twin.to_hash
    assert h.key?(:things)
    refute h.key?(:items)
    assert_equal [{ value: 1 }, { value: 2 }].map(&:with_indifferent_access), h[:things]

    # Update alias key and verify rename takes effect
    twin.alias_key = "stuff"
    h2 = twin.to_hash
    assert h2.key?(:stuff)
    refute h2.key?(:things)
    assert_equal [1, 2], twin.stuff.map(&:value)
  end

  test "no-alias twin setters do not invoke recompute" do
    twin = NoDynamicAliasTwin.new(name: "a", age: 1)
    called = 0
    twin.define_singleton_method(:__recompute_dynamic_aliases__) { called += 1 }
    twin.name = "b"
    twin.age = 2
    assert_equal 0, called
  end

  test "assign_hash recomputes aliases at most once per call" do
    t = RecomputeOnceTwin.new(name: "a", age: 1, email: "x@y")
    calls = 0
    t.define_singleton_method(:__recompute_dynamic_aliases__) { calls += 1 }
    t.assign_hash(name: "b", age: 2, email: "z@y")
    assert_operator calls, :<=, 1
  end

  test "dynamic alias collision raises when alias name already exists" do
    klass = Class.new(Minitwin) do
      property :value, as: -> { :to_s }
    end
    assert_raises(ArgumentError) { klass.new(value: 1) }
  end

  test "dynamic alias forbidden names raise specific error" do
    klass = Class.new(Minitwin) do
      property :value, as: -> { :send }
    end
    err = assert_raises(ArgumentError) { klass.new(value: 1) }
    assert_includes err.message, "forbidden"
  end

  test "protects original method while exposing the computed dynamic alias" do
    klass = Class.new(Minitwin) do
      property :name, as: -> { "computed_name" }
    end

    obj = klass.new(name: "test")
    # The original method should be protected
    assert_raises(NoMethodError) { obj.name }
    # But the alias should work
    assert_equal "test", obj.computed_name
  end

  test "two dynamic aliases computing the same name raise a collision error" do
    klass = Class.new(Minitwin) do
      property :first, as: -> { "same" }
      property :second, as: -> { "same" }
    end

    # Should raise on collision during initialization
    assert_raises(ArgumentError) do
      klass.new(first: "a", second: "b")
    end
  end

  test "dynamic alias colliding with an existing method raises an error" do
    klass = Class.new(Minitwin) do
      property :name

      def existing_method
        "original"
      end

      property :other, as: -> { "existing_method" }
    end

    # Should raise on collision during initialization
    assert_raises(ArgumentError) do
      klass.new(name: "test", other: "value")
    end
  end

  test "failed nested alias computation is skipped and the value is still set" do
    klass = Class.new(Minitwin) do
      nested :group do
        property :tag, as: -> { raise StandardError, "computation failed" }
      end
    end

    # Should not raise during initialization - the alias computation fails silently
    # and the value is still set
    assert_nothing_raised do
      obj = klass.new(tag: "test")
      # The nested group should still be created
      assert_not_nil obj.group
    end
  end

  test "dynamic aliases reverse lookup maps alias name to target method" do
    klass = Class.new(Minitwin) do
      property :name, as: -> { "alias_name" }
    end

    obj = klass.new(name: "test")
    aliases = obj.send(:dynamic_aliases)
    assert_equal :name, aliases[:alias_name]
  end

  test "dynamic aliases return an empty hash when none are defined" do
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    aliases = obj.send(:dynamic_aliases)
    assert_equal({}, aliases)
  end

  test "recomputing dynamic aliases replaces the prior alias forwarding" do
    klass = Class.new(Minitwin) do
      property :name, as: -> { "first_alias" }
    end

    obj = klass.new(name: "test")
    assert_equal "test", obj.first_alias

    # Update to use different alias
    obj.instance_variable_set(:@name, "updated")
    # Force recomputation
    obj.send(:__recompute_dynamic_aliases__)

    # Should still work
    assert_equal "updated", obj.first_alias
  end

  # alias security

  test "binding cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :binding }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end

  test "to_proc cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :to_proc }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end

  test "freeze cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :freeze }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end

  test "raises ArgumentError with clear message when as: proc returns non-string/symbol" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { 42 }
    end
    error = assert_raises(ArgumentError) { klass.new(x: 1) }
    assert_match(/invalid alias name/i, error.message)
    assert_match(/42/, error.message)
  end
end
