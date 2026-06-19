# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class CoercionTest < ActiveSupport::TestCase
  # === embedding sub twins via twin: ===

  class SubTwin < Minitwin
    property :sub_property
    property :another_sub_property, default: "default"
  end

  class EmbeddingTwin < Minitwin
    property :sub_twin, twin: SubTwin
    collection :sub_twins, twin: SubTwin
  end

  test "embeds sub twins via twin option for property and collection" do
    obj = EmbeddingTwin.from_hash(
      {
        sub_twin: { sub_property: "test sub property" },
        sub_twins: [
          { sub_property: "test", another_sub_property: "another test" },
          { sub_property: "second property" }
        ]
      }
    )
    assert_instance_of SubTwin, obj.sub_twin
    assert_equal "test sub property", obj.sub_twin.sub_property
    assert_equal 2, obj.sub_twins.size
    assert_equal "test", obj.sub_twins.first.sub_property
    assert_equal "another test", obj.sub_twins.first.another_sub_property
    assert_equal "second property", obj.sub_twins.last.sub_property
    assert_equal "default", obj.sub_twins.last.another_sub_property
  end

  # === twin property coercion from hash / nil ===

  test "coerces hash into twin property" do
    inner = Class.new(Minitwin) do
      property :value
    end

    outer = Class.new(Minitwin) do
      property :inner, twin: inner
    end

    obj = outer.new(inner: { value: "test" })
    assert_instance_of inner, obj.inner
    assert_equal "test", obj.inner.value
  end

  test "twin property with nil value stays nil" do
    inner = Class.new(Minitwin) do
      property :value
    end

    outer = Class.new(Minitwin) do
      property :inner, twin: inner
    end

    obj = outer.new(inner: nil)
    assert_nil obj.inner
  end

  # === array pair format ===

  test "coerces array pair [id, hash] format into twin" do
    klass = Class.new(Minitwin) do
      property :name
    end

    nested_klass = Class.new(Minitwin) do
      property :item, twin: klass
    end

    # Array pair format: [id, hash_of_attributes] is a special Rails-style format
    # Only works when the array has exactly 2 elements and last is a Hash
    # The first element can be any object (typically an ID)
    obj = nested_klass.new(item: [123, { name: "test" }])
    assert_equal "test", obj.item.name
  end

  # === reflection / instance variable fallback ===

  test "coerces object without to_h, attributes, or known methods via instance variables" do
    simple_object = Object.new
    simple_object.instance_variable_set(:@name, "test")
    simple_object.instance_variable_set(:@value, 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    # Should extract from instance variables as fallback
    obj = klass.from_object(simple_object)
    assert_equal "test", obj.name
    assert_equal 42, obj.value
  end

  test "coercion returns nil when no instance variables present" do
    simple_object = Object.new

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should not raise when no instance variables exist
    obj = klass.from_object(simple_object)
    assert_nil obj.name
  end

  test "coercion extracts instance variables when no readers present" do
    val = Class.new do
      def initialize
        @foo = 9
      end
    end.new
    inner = Class.new(Minitwin) do
      property :foo
    end
    outer = Class.new(Minitwin) do
      property :child, twin: inner
    end
    obj = outer.new
    obj.child = val
    assert_equal 9, obj.child.foo
  end

  test "coercion tolerates method call failures during reflection" do
    # Create an object that responds but raises on call
    bad_object = Object.new
    def bad_object.name
      raise "method failed"
    end

    def bad_object.respond_to?(method, include_private = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
      return true if method == :name

      super
    end

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should handle the error gracefully - won't set the property
    obj = klass.from_object(bad_object)
    assert_instance_of klass, obj
  end

  # === collection coercion ===

  test "coerces single-element array into collection" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    # Pass a single hash inside an array - should be wrapped in array
    obj = klass.new(items: [{ name: "single" }])
    assert_equal 1, obj.items.length
    assert_equal "single", obj.items.first.name
  end

  test "enrich_attrs_from_readers! collection path coerces non-array reader via Array(raw)" do
    src = Class.new do
      def attributes
        {}
      end

      def items
        Object.new
      end
    end.new
    container = Class.new(Minitwin) do
      collection :items
    end
    res = container.send(:coerce_value_to_twin, src, container)
    assert_kind_of container, res
    assert_kind_of Array, res.items
  end
end
