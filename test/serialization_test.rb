# frozen_string_literal: true

require "test_helper"
require "mini_twin"
require "pp"
require "stringio"

class SerializationTest < ActiveSupport::TestCase
  class WidgetTwin < Minitwin
    property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
    property :unexposed_prop, expose: false
    property :wrong_lego, as: :lego do
      property :brick, default: 0
    end
    property :an_array
    collection :empty_array
    collection :cool_stuff, as: :list_of_stuff do
      property :property
    end
    property :sub_twin do
      property :sub_property
    end
  end

  class TagCollectionTwin < Minitwin
    collection :values
  end

  class TagTwin < Minitwin
    property :my_value
  end

  class PersonTwin < Minitwin
    property :name
  end

  class EmployeeTwin < PersonTwin
    property :age
  end

  test "to_hash produces indifferent-access hash and omits unexposed properties" do
    obj = WidgetTwin.from_hash(
      wrong_runtime: "3",
      wrong_lego: { brick: 123 },
      unexposed_prop: "ignore me",
      cool_stuff: [{ property: "test" }],
      an_array: [1, 2, 3],
      sub_twin: {}
    )

    hash = obj.to_hash
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
    assert_nil hash["unexposed_prop"]
    assert_nil hash["wrong_runtime"]
    assert_equal 3, hash["runtime"]
    assert_equal 123, hash[:lego][:brick]
    assert_equal [1, 2, 3], hash[:an_array]
    assert_equal [], hash[:empty_array]
    assert_not hash["sub_twin"].key?(:sub_property)
  end

  test "pretty_print formats output with class name and key attributes" do
    obj = WidgetTwin.from_hash(
      wrong_runtime: "42",
      wrong_lego: { brick: 100 },
      cool_stuff: [{ property: "item1" }, { property: "item2" }],
      an_array: [1, 2, 3],
      sub_twin: { sub_property: "nested" }
    )

    # Capture pretty_print output
    output = StringIO.new
    PP.pp(obj, output)
    result = output.string

    # Verify output contains the class name and key attributes
    assert_includes result, "WidgetTwin"
    assert_includes result, "runtime"
    assert_includes result, "42"
    assert_includes result, "lego"
    assert_includes result, "brick"
  end

  test "pretty_print renders nested objects" do
    obj = WidgetTwin.from_hash(
      sub_twin: { sub_property: "deep nested value" }
    )

    output = StringIO.new
    PP.pp(obj, output)
    result = output.string

    assert_includes result, "sub_twin"
    assert_includes result, "sub_property"
    assert_includes result, "deep nested value"
  end

  test "pretty_print renders collections" do
    obj = WidgetTwin.from_hash(
      cool_stuff: [
        { property: "first" },
        { property: "second" }
      ]
    )

    output = StringIO.new
    PP.pp(obj, output)
    result = output.string

    assert_includes result, "list_of_stuff"
    assert_includes result, "first"
    assert_includes result, "second"
  end

  test "collection of twins serializes element values" do
    collection_twin = TagCollectionTwin.new
    value_twins = [TagTwin.new(my_value: "foo")]
    collection_twin.values = value_twins
    h = collection_twin.to_hash
    assert_equal "foo", h[:values].first[:my_value]
  end

  test "child twin serializes inherited property via to_hash" do
    c = EmployeeTwin.new(name: "x", age: 1)
    h = c.to_hash
    assert_equal "x", h[:name]
    assert_equal 1, h[:age]
  end

  test "child twin attributes include inherited property" do
    c = EmployeeTwin.new(name: "y", age: 2)
    assert_equal({ name: "y", age: 2 }, c.attributes.slice(:name, :age))
  end

  test "expose: false excludes property from to_hash" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :token, expose: false
    end
    twin = twin_class.new(name: "Alice", token: "secret")
    assert_equal({ name: "Alice" }.with_indifferent_access, twin.to_hash)
  end

  test "expose: true (default) includes property in to_hash" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :score, expose: true
    end
    twin = twin_class.new(name: "Bob", score: 42)
    assert_equal({ name: "Bob", score: 42 }.with_indifferent_access, twin.to_hash)
  end

  test "expose: false property is still readable via getter" do
    twin_class = Class.new(Minitwin) do
      property :token, expose: false
    end
    twin = twin_class.new(token: "abc")
    assert_equal "abc", twin.token
  end

  test "unexposed_properties lists properties with expose: false" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :token, expose: false
    end
    assert_includes twin_class.unexposed_properties, :token
    refute_includes twin_class.unexposed_properties, :name
  end

  test "properties metadata stores expose: key" do
    twin_class = Class.new(Minitwin) do
      property :token, expose: false
    end
    refute twin_class.properties[:token][:expose]
  end

  test "attributes returns base keys even when aliased" do
    t = Class.new(Minitwin) do
      property :secret_value, as: :public_value, default: 10
    end.new
    # The public getter is aliased
    assert_equal 10, t.public_value
    # Original getter is protected
    assert_raises(NoMethodError) { t.secret_value }

    attrs = t.attributes
    # Attributes should include the setter/base name and value
    assert_equal({ secret_value: 10 }, attrs)
  end

  test "dynamic aliases appear in pretty_print pair output" do
    klass = Class.new(Minitwin) do
      property :key
      property :value, as: -> { key }
    end
    twin = klass.new(key: "alias", value: 1)
    pairs = twin.send(:dynamic_aliases_for_pp)
    assert_includes pairs, [:alias, 1]
  end

  test "unexposed properties are excluded from serialization" do
    klass = Class.new(Minitwin) do
      property :name
      property :internal, expose: false
    end

    obj = klass.new(name: "test", internal: "secret")
    hash = obj.to_hash

    assert_equal "test", hash[:name]
    refute hash.key?(:internal)
  end

  test "to_hash with render_nil option includes nil values" do
    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new(name: "test", value: nil)
    hash = obj.to_hash(render_nil: true)

    assert hash.key?(:value)
    assert_nil hash[:value]
  end

  test "to_json serializes properties" do
    klass = Class.new(Minitwin) do
      property :name
      property :value
    end

    obj = klass.new(name: "test", value: 42)
    json = obj.to_json

    assert_includes json, '"name":"test"'
    assert_includes json, '"value":42'
  end

  test "attributes accesses protected readers" do
    klass = Class.new(Minitwin) do
      property :name, as: :full_name
    end

    obj = klass.new(name: "test")
    attrs = obj.attributes

    # Should access protected original reader
    assert_equal "test", attrs[:name]
  end

  test "to_hash returns a plain Hash when HashWithIndifferentAccess is unavailable" do
    # Temporarily hide HashWithIndifferentAccess
    begin
      Object.const_get(:HashWithIndifferentAccess)
    rescue StandardError
      nil
    end

    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    hash = obj.to_hash
    # Should still work, just return regular Hash
    assert_kind_of Hash, hash
    assert_equal "test", hash[:name]
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

  test "ordered_attributes_for_pp without property_order and inspect formatting" do
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

  test "valid? returns true without activemodel" do
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
    assert_predicate obj, :valid?
  end
end
