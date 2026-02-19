require "test_helper"
require "mini_twin"

class MiniTwinCoreTest < ActiveSupport::TestCase
  test "should expose VERSION and DSL" do
    assert MiniTwin::VERSION

    klass = Class.new(MiniTwin) do
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
    klass = Class.new(MiniTwin) do
      property :a
    end
    # Hide serializable_getters to force else branch
    def klass.respond_to?(name, include_private=false)
      return false if name == :serializable_getters && include_private
      super
    end
    twin = klass.new(a: 1)
    assert_equal({ a: 1 }.with_indifferent_access, twin.to_hash)
  end

  test "ordered_methods_for_pp else branch and inspect formatting" do
    klass = Class.new(MiniTwin) do
      property :a
      property :b
    end
    def klass.respond_to?(name, include_private=false)
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

  test "inherited hook tracks descendants of MiniTwin subclasses" do
    # Create a direct subclass of MiniTwin
    parent_klass = Class.new(MiniTwin) do
      property :id
    end

    # Create a subclass of the subclass (not directly from MiniTwin)
    child_klass = Class.new(parent_klass) do
      property :name
    end

    # Both should be tracked in MiniTwin.__descendants__
    assert_includes MiniTwin.__descendants__, parent_klass,
      "Direct MiniTwin subclass should be tracked"
    assert_includes MiniTwin.__descendants__, child_klass,
      "Subclass of MiniTwin subclass should also be tracked in MiniTwin.__descendants__"
  end
end
