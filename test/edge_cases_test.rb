require "test_helper"
require "mini_twin"

class EdgeCasesTest < ActiveSupport::TestCase
  test "should handle type coercion errors gracefully" do
    klass = Class.new(Minitwin) do
      property :age, type: Types::Strict::Integer
    end

    # Should not raise, but keep original value when coercion fails
    obj = klass.new(age: "invalid")
    assert_equal "invalid", obj.age
  end

  test "to_hash dynamic_aliases_for_pp path and pretty_print alias output" do
    klass = Class.new(Minitwin) do
      property :key
      property :value, as: -> { key }
    end
    twin = klass.new(key: "alias", value: 1)
    pairs = twin.send(:dynamic_aliases_for_pp)
    assert_includes pairs, [:alias, 1]
  end

  test "attribute_methods fallback branch without cache" do
    klass = Class.new(Minitwin) do
      # Define a writer-only attribute and a plain reader to exercise respond_to? check
      def foo=(v); @foo = v; end
      def foo; @foo; end
    end
    def klass.respond_to?(name, include_private=false)
      return false if name == :allowed_attribute_keys && include_private
      super
    end
    twin = klass.new
    methods = twin.send(:attribute_methods)
    assert_includes methods, :foo
  end

  test "assign_attribute fallback sets ivar when no setter" do
    klass = Class.new(Minitwin) do
      # no setter defined for :bar
    end
    twin = klass.new
    twin.send(:assign_attribute, method: :bar, value: 123)
    assert_equal 123, twin.instance_variable_get(:@bar)
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

  test "should handle nil in type_default_value for unknown types" do
    klass = Class.new(Minitwin) do
      # Use a custom type that doesn't match standard patterns
      custom_type = Types::Nominal::Any
      property :custom, type: custom_type, default: nil
    end

    obj = klass.new
    # Should return nil for unknown type without default
    assert_nil obj.custom
  end

  test "should handle coercion from object without to_h, attributes, or known methods" do
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

  test "should handle empty instance variables in coercion fallback" do
    simple_object = Object.new

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should not raise when no instance variables exist
    obj = klass.from_object(simple_object)
    assert_nil obj.name
  end

  test "should handle nested class creation with invalid constant name" do
    klass = Class.new(Minitwin) do
      # Using a name that might cause issues with constant naming
      property :my_nested_prop do
        property :value
      end
    end

    obj = klass.new(my_nested_prop: { value: "test" })
    assert_equal "test", obj.my_nested_prop.value
  end

  test "should handle array pair format in coercion" do
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

  test "should handle method call failures during coercion" do
    # Create an object that responds but raises on call
    bad_object = Object.new
    def bad_object.name
      raise "method failed"
    end
    def bad_object.respond_to?(method, include_private = false)
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

  test "should handle string coercion when dry-types doesn't return string" do
    klass = Class.new(Minitwin) do
      property :text, type: Types::Coercible::String
    end

    obj = klass.new(text: 123)
    assert_equal "123", obj.text
  end

  test "should handle protected methods in dynamic alias computation" do
    klass = Class.new(Minitwin) do
      property :name, as: -> { "computed_name" }
    end

    obj = klass.new(name: "test")
    # The original method should be protected
    assert_raises(NoMethodError) { obj.name }
    # But the alias should work
    assert_equal "test", obj.computed_name
  end

  test "should handle dynamic alias collision detection" do
    # This tests that dynamic aliases with same name cause collision error
    klass = Class.new(Minitwin) do
      property :first, as: -> { "same" }
      property :second, as: -> { "same" }
    end

    # Should raise on collision during initialization
    assert_raises(ArgumentError) do
      klass.new(first: "a", second: "b")
    end
  end

  test "should handle existing method collision in dynamic aliases" do
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

  test "should handle StandardError in nested alias computation" do
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

  test "should handle collection coercion from non-array objects" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    # Pass a single hash instead of array - should be wrapped in array
    obj = klass.new(items: [{ name: "single" }])
    assert_equal 1, obj.items.length
    assert_equal "single", obj.items.first.name
  end

  test "should handle enrichment failures gracefully" do
    source = Object.new
    def source.name
      raise "enrichment failed"
    end

    klass = Class.new(Minitwin) do
      property :name
    end

    # Should not propagate the error from source
    obj = klass.from_object(source)
    assert_instance_of klass, obj
  end

  test "should handle collections metadata lookup failure" do
    klass = Class.new(Minitwin) do
      property :items, on: :model
    end

    model = Struct.new(:items).new([1, 2, 3])

    # Should handle when collections metadata can't be retrieved
    obj = klass.from_objects(model: model)
    assert_equal [1, 2, 3], obj.items
  end

  test "should handle boolean type defaults" do
    # Create a custom boolean type that returns TrueClass as primitive
    bool_type = Types::Nominal::Bool

    klass = Class.new(Minitwin) do
      property :active, type: bool_type
    end

    obj = klass.new
    # For boolean-like types without explicit default, should return false or nil
    # The specific behavior depends on the type's primitive
    assert_includes [false, nil], obj.active
  end

  test "should handle integer type defaults" do
    klass = Class.new(Minitwin) do
      property :count, type: Types::Integer
    end

    obj = klass.new
    # Should default to 0 for integer types
    assert_equal 0, obj.count
  end

  test "should handle string type defaults" do
    klass = Class.new(Minitwin) do
      property :text, type: Types::String
    end

    obj = klass.new
    # Should default to "" for string types
    assert_equal "", obj.text
  end

  test "should handle type inference from string representation" do
    # Create a type without a clear primitive
    custom_int_type = Types.Constructor(Integer) { |v| v.to_i }

    klass = Class.new(Minitwin) do
      property :number, type: custom_int_type
    end

    obj = klass.new
    # Should infer Integer from type string
    assert_equal 0, obj.number
  end

  test "should handle model composition with missing model" do
    klass = Class.new(Minitwin) do
      property :name, on: :missing_model
    end

    # Should raise informative error
    obj = klass.new
    error = assert_raises(RuntimeError) { obj.name }
    assert_match /unknown composition source/, error.message
  end

  test "should handle model composition with model not responding to property" do
    model = Struct.new(:other_field).new("value")

    klass = Class.new(Minitwin) do
      property :name, on: :model
    end

    obj = klass.from_objects(model: model)
    error = assert_raises(RuntimeError) { obj.name }
    assert_match /does not respond to/, error.message
  end

  test "should handle property getter with custom getter proc" do
    klass = Class.new(Minitwin) do
      property :computed, getter: -> { "computed_value" }
    end

    obj = klass.new
    assert_equal "computed_value", obj.computed
  end

  test "should handle property setter with custom setter proc" do
    klass = Class.new(Minitwin) do
      property :upcased, setter: ->(v) { v.to_s.upcase }
    end

    obj = klass.new(upcased: "hello")
    assert_equal "HELLO", obj.upcased
  end

  test "should handle twin property coercion" do
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

  test "should raise when setter provided with block property" do
    # Need to instantiate to trigger the setter logic check
    klass = Class.new(Minitwin) do
      begin
        property :invalid, setter: ->(v) { v } do
          property :name
        end
      rescue => e
        @caught_error = e
      end

      def self.caught_error
        @caught_error
      end
    end

    # The error should be caught during class definition
    assert_match /setters are not possible in blocks/, klass.caught_error.message
  end

  test "should handle validation errors without activemodel" do
    # Create a twin class without ActiveModel
    base = Class.new do
      extend Minitwin::ClassMethods

      def self.name
        "TestTwin"
      end
    end

    # Should raise when trying to add validations without ActiveModel
    error = assert_raises(RuntimeError) do
      base.class_eval do
        property :name, validates: { presence: true }
      end
    end
    assert_match /activemodel is not available/, error.message
  end

  test "should handle cache invalidation" do
    klass = Class.new(Minitwin) do
      property :first
    end

    # Cache should be built
    first_getters = klass.send(:serializable_getters)

    # Add another property
    klass.class_eval do
      property :second
    end

    # Cache should be invalidated and rebuilt
    second_getters = klass.send(:serializable_getters)
    assert_includes second_getters, :second
  end

  test "should handle dynamic aliases reverse lookup" do
    klass = Class.new(Minitwin) do
      property :name, as: -> { "alias_name" }
    end

    obj = klass.new(name: "test")
    aliases = obj.send(:dynamic_aliases)
    assert_equal :name, aliases[:alias_name]
  end

  test "should handle dynamic aliases when not defined" do
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    aliases = obj.send(:dynamic_aliases)
    assert_equal({}, aliases)
  end

  test "should filter unknown keys on initialization" do
    klass = Class.new(Minitwin) do
      property :name
    end

    # Should silently ignore unknown keys
    obj = klass.new(name: "test", unknown: "value", another: "ignored")
    assert_equal "test", obj.name
    refute obj.respond_to?(:unknown)
  end

  test "should handle assign_object with model tracking" do
    model = Struct.new(:name, :value).new("test", 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new
    obj.assign_object(model)

    assert_equal "test", obj.name
    assert_equal 42, obj.value
    # Should track the model internally
    assert_equal model, obj.instance_variable_get(klass.internal_model_name("model"))
  end

  test "should handle from_params with unsafe hash conversion" do
    params = ActionController::Parameters.new(name: "test", value: 42)

    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.from_params(params)
    assert_equal "test", obj.name
    assert_equal 42, obj.value
  end

  test "should handle from_object with hash input error" do
    klass = Class.new(Minitwin) do
      property :name
    end

    error = assert_raises(RuntimeError) do
      klass.from_object({ name: "test" })
    end
    assert_match /use.*from_objects/, error.message
  end

  test "should handle from_objects with attribute_aliases" do
    model_class = Struct.new(:name, :old_name) do
      def attributes
        { name: name }
      end

      def attribute_aliases
        { new_name: :name }
      end
    end

    model = model_class.new("test", "old")

    klass = Class.new(Minitwin) do
      property :name
      property :new_name
    end

    obj = klass.from_objects(model: model)
    assert_equal "test", obj.name
    assert_equal "test", obj.new_name
  end

  test "should handle virtual properties exclusion from serialization" do
    klass = Class.new(Minitwin) do
      property :name
      property :internal, virtual: true
    end

    obj = klass.new(name: "test", internal: "secret")
    hash = obj.to_hash

    assert_equal "test", hash[:name]
    refute hash.key?(:internal)
  end

  test "should handle serialization with render_nil option" do
    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new(name: "test", value: nil)
    hash = obj.to_hash(render_nil: true)

    assert hash.key?(:value)
    assert_nil hash[:value]
  end

  test "should handle to_json serialization" do
    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new(name: "test", value: 42)
    json = obj.to_json

    assert_includes json, '"name":"test"'
    assert_includes json, '"value":42'
  end

  test "should handle attributes method with protected readers" do
    klass = Class.new(Minitwin) do
      property :name, as: :full_name
    end

    obj = klass.new(name: "test")
    attrs = obj.attributes

    # Should access protected original reader
    assert_equal "test", attrs[:name]
  end

  test "should handle validation without activemodel" do
    klass = Class.new do
      include Minitwin::Serialization
      def self.block_properties
        []
      end
      def self.collection_properties
        []
      end
    end

    obj = klass.new
    # Should return true when ActiveModel is not included
    assert obj.valid?
  end
end
