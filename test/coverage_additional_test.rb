# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class CoverageAdditionalTest < ActiveSupport::TestCase
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

  test "assign_attribute uses setter branch when available" do
    klass = Class.new(Minitwin) do
      attr_writer :foo

      attr_reader :foo
    end
    obj = klass.new
    obj.send(:assign_attribute, method: :foo, value: 42)
    assert_equal 42, obj.foo
  end

  test "composition getter returns default and type default when raw is nil" do
    model = Struct.new(:name, :age).new(nil, nil)
    twin = Class.new(Minitwin) do
      property :name, on: :model, default: "x"
      property :age, on: :model, type: Types::Integer
    end.from_object(model)
    assert_equal "x", twin.name
    assert_equal 0, twin.age
  end

  test "sync read NoMethodError path via allowed_attribute_keys without getter" do
    model = Class.new do
      attr_reader :written

      def missing_getter=(_)
        @written = true
      end
    end.new
    twin = Class.new(Minitwin) do
      def self.allowed_attribute_keys
        Set[:missing_getter]
      end

      def missing_getter=(value)
        @missing = value
      end
    end.new
    assert twin.sync(model)
    assert model.written
  end

  test "sync collection index rescue path with [] raising accesses" do
    coll = Class.new do
      def initialize(arr)
        @arr = arr
      end

      def each(&blk)
        @arr.each(&blk)
      end

      def [](_)
        raise "boom"
      end
    end
    item = Struct.new(:val)
    m = Class.new do
      attr_reader :items
      attr_reader :assigned

      def initialize(items)
        @items = items
      end

      def items=(value)
        @assigned = value
      end
    end.new(coll.new([item.new("a"), item.new("b")]))

    twin = Class.new(Minitwin) do
      collection :items do
        property :val
      end
    end.new(items: [{ val: "A" }, { val: "B" }])

    assert twin.sync(m)
    # Writer fallback performed due to [] rescue
    assert_equal([{ val: "A" }.with_indifferent_access, { val: "B" }.with_indifferent_access], m.assigned)
  end

  test "build_target_id_lookup elsif branch via Array subclass without to_a in respond_to?" do
    item = Struct.new(:id, :value)
    weird = Class.new(Array) do
      def respond_to?(method_name, inc = false) # rubocop: disable Style/OptionalBooleanParameter -- is method overwrite from `Object`
        return false if method_name == :to_a

        super
      end
    end
    array = weird.new([item.new(1, "a"), item.new(2, "b")])

    m = Struct.new(:items).new(array)

    twin = Class.new(Minitwin) do
      collection :items do
        property :id
        property :value
      end
    end.from_object(m)

    twin.items = [{ id: 1, value: "A1" }, { id: 2, value: "B2" }]
    assert twin.sync(m)
    assert_equal "A1", m.items[0].value
    assert_equal "B2", m.items[1].value
  end

  test "rbs untyped element type when collection has no element twin and unknown type maps to untyped" do
    dummy_t = Class.new do
      def to_s
        "Mystery"
      end

      def inspect
        "Mystery"
      end

      def class
        Struct
      end

      def call(_)
        raise "nope"
      end
    end.new

    klass = Class.new(Minitwin) do
      def self.name
        "UntypedTwin"
      end
      property :myst, type: dummy_t
      collection :stuff
    end
    rbs = klass.to_rbs
    assert_includes rbs, "myst: untyped"
    assert_includes rbs, "attr_accessor stuff: ::Array[untyped]"
  end

  test "caches setter_methods builds cache" do
    k = Class.new(Minitwin) do
      property :a
      property :b
    end
    setters = k.send(:setter_methods)
    assert_includes setters, :a=
    assert_includes setters, :b=
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

  test "enrich_attrs_from_readers! collection path and coerce_collection_array Array(raw) path" do
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
