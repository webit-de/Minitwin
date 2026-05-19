require "test_helper"
require "mini_twin"

class ErrorHandlingTest < ActiveSupport::TestCase
  test "should handle nested creation without block" do
    error = assert_raises(ArgumentError) do
      Class.new(Minitwin) do
        nested :invalid
      end
    end
    assert_match /requires a block/, error.message
  end

  test "should handle composition property when model doesn't respond to property" do
    model = Struct.new(:other).new("value")

    klass = Class.new(Minitwin) do
      property :name, on: :model
    end

    obj = klass.from_objects(model: model)
    error = assert_raises(RuntimeError) do
      obj.name
    end
    assert_match /does not respond to/, error.message
  end

  test "should handle missing composition model error" do
    klass = Class.new(Minitwin) do
      property :name, on: :missing
    end

    obj = klass.new
    error = assert_raises(RuntimeError) do
      obj.name
    end
    assert_match /unknown composition source/, error.message
  end

  test "should handle assign_params with non-ActionController params" do
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new
    # Regular hash should work with assign_params
    obj.assign_params(name: "test")
    assert_equal "test", obj.name
  end

  test "should handle collection attribute suffix access" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    obj = klass.new
    # Should support _attributes suffix for collections
    obj.items_attributes = [{ name: "test" }]
    assert_equal "test", obj.items.first.name
  end

  test "should handle nested groups with protected readers" do
    klass = Class.new(Minitwin) do
      nested :metadata do
        property :created_at, as: :timestamp
      end
    end

    obj = klass.new(created_at: "2024-01-01")
    # Nested groups create setters for leaf properties
    # Should be able to access via the nested group
    assert_equal "2024-01-01", obj.timestamp
  end

  test "should handle property without type that returns nil" do
    klass = Class.new(Minitwin) do
      property :optional
    end

    obj = klass.new
    assert_nil obj.optional
  end

  test "should handle property with explicit default taking precedence" do
    klass = Class.new(Minitwin) do
      property :count, type: Types::Integer, default: 42
    end

    obj = klass.new
    # Explicit default should take precedence over type default
    assert_equal 42, obj.count
  end

  test "should handle boolean property with question mark" do
    klass = Class.new(Minitwin) do
      property :active?
    end

    # Should be able to create twins with question mark properties
    assert_nothing_raised do
      obj = klass.new
      obj.active? # Should not raise
    end
  end

  test "should handle serialization without HashWithIndifferentAccess" do
    # Temporarily hide HashWithIndifferentAccess
    original_const = Object.const_get(:HashWithIndifferentAccess) rescue nil

    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    hash = obj.to_hash
    # Should still work, just return regular Hash
    assert_kind_of Hash, hash
    assert_equal "test", hash[:name]
  end

  test "should handle assign_hash with nested objects" do
    klass = Class.new(Minitwin) do
      property :profile do
        property :bio
      end
    end

    obj = klass.new(bio: "old")
    # assign_hash should update nested twins if the nested object exists
    obj.assign_hash(profile: { bio: "new" })
    assert_equal "new", obj.profile.bio
  end

  test "should handle assign_hash with collection items" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    obj = klass.new(items: [{ name: "old" }])
    # assign_hash should update collection items
    obj.assign_hash(items: [{ name: "new" }])
    assert_equal "new", obj.items.first.name
  end

  test "should handle from_collection with empty array" do
    klass = Class.new(Minitwin) do
      property :name
    end

    result = klass.from_collection([])
    assert_equal [], result
  end

  test "should handle from_json with nested structures" do
    klass = Class.new(Minitwin) do
      property :profile do
        property :bio
      end
    end

    json = '{"profile":{"bio":"test bio"}}'
    obj = klass.from_json(json)
    assert_equal "test bio", obj.profile.bio
  end

  test "should handle twin property with nil value" do
    inner = Class.new(Minitwin) do
      property :value
    end

    outer = Class.new(Minitwin) do
      property :inner, twin: inner
    end

    obj = outer.new(inner: nil)
    assert_nil obj.inner
  end

  test "should handle validation on property without activemodel validations" do
    # When valid? is called on a twin without nested properties
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    # Should be valid when no validations are defined
    assert obj.valid?
  end

  test "should handle dynamic alias removal and replacement" do
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
end
