# frozen_string_literal: true

require "test_helper"
require "minitwin"

class DslCompositionTest < ActiveSupport::TestCase

  test "from_objects composes properties from several source models" do
    customer = Data.define(:id, :name).new(id: 123, name: "Petra Rodriguez")
    address = Data.define(:id, :street, :latitude).new(id: "abc", street: "1234 fake street", latitude: 55.76)
    klass = Class.new(Minitwin) do
      property :id, as: :customer_id, on: :customer
      property :id, as: :address_id, on: :address
      property :name, on: :customer
      property :street, on: :address
      property :latitude, on: :address, expose: false
      property :country, default: "D"
    end
    obj = klass.from_objects(customer:, address:)

    assert_equal 123, obj.customer_id
    assert_equal "abc", obj.address_id
    assert_equal "Petra Rodriguez", obj.name
    assert_equal "1234 fake street", obj.street
    assert_equal "D", obj.country
    assert_in_delta(55.76, obj.latitude)

    hash = obj.to_hash
    assert_equal "abc", hash[:address_id]
    assert_equal 123, hash[:customer_id]
    assert_equal "Petra Rodriguez", hash[:name]
    assert_equal "1234 fake street", hash[:street]
    assert_equal "D", hash[:country]
    assert_nil hash[:latitude]
  end

  test "composition with a proc source resolves the property through the proc" do
    address = Data.define(:id, :street).new(id: "abc", street: "1234 fake street")
    customer = Data.define(:id, :name, :address).new(id: 123, name: "Petra Rodriguez", address:)

    klass = Class.new(Minitwin) do
      property :customer, expose: false
      property :name, on: :customer
      property :street, on: -> { customer.address }
    end
    obj = klass.new(customer:)

    assert_equal "Petra Rodriguez", obj.name
    assert_equal "1234 fake street", obj.street

    assert_equal({ "name" => "Petra Rodriguez", "street" => "1234 fake street" }, obj.to_hash)
  end

  test "on: flattens values out of an inline block twin via a symbol and a proc source" do
    klass = Class.new(Minitwin) do
      property :address, expose: false do
        property :city
        property :installation do
          property :street
        end
      end

      property :city, on: :address
      property :street, on: -> { address.installation }
    end
    obj = klass.from_hash(address: { city: "Berlin", installation: { street: "1234 fake street" } })

    assert_equal "Berlin", obj.city
    assert_equal "1234 fake street", obj.street
    assert_equal({ "city" => "Berlin", "street" => "1234 fake street" }, obj.to_hash)

    # The projection is read-only: the generated setter writes an ivar that the
    # composition getter never reads.
    obj.city = "Hamburg"
    assert_equal "Berlin", obj.city
  end

  test "collection with on: wraps a non-Array relation into element twins" do
    items = [RelationItem.new(sub: "x"), RelationItem.new(sub: "y")]
    contract = ContractWithRelation.new(items: items)
    klass = Class.new(Minitwin) do
      collection :items, on: :contract do
        property :sub, as: :renamed
      end
    end
    twin = klass.from_objects(contract: contract)

    assert_equal 2, twin.items.size
    assert_kind_of Minitwin, twin.items.first
    assert_equal "x", twin.items.first.renamed
    assert_equal "y", twin.items.last.renamed
  end

  test "composition getter rescues errors raised during collections meta lookup" do
    src = Struct.new(:foo).new("value")
    klass = Class.new(Minitwin) do
      property :foo, on: :src
    end
    t = klass.from_objects(src: src)

    def klass.collections(*)
      raise "boom"
    end

    assert_equal "value", t.foo
  end

  test "composition with a missing model raises an unknown composition source error" do
    klass = Class.new(Minitwin) do
      property :name, on: :missing_model
    end

    # Should raise informative error
    obj = klass.new
    error = assert_raises(RuntimeError) { obj.name }
    assert_match(/unknown composition source/, error.message)
  end

  test "composition with a model not responding to the property raises an error" do
    model = Struct.new(:other_field).new("value")

    klass = Class.new(Minitwin) do
      property :name, on: :model
    end

    obj = klass.from_objects(model: model)
    error = assert_raises(RuntimeError) { obj.name }
    assert_match(/does not respond to/, error.message)
  end

  test "composition returns the raw value when collections metadata lookup fails" do
    klass = Class.new(Minitwin) do
      property :items, on: :model
    end

    model = Struct.new(:items).new([1, 2, 3])

    # Should handle when collections metadata can't be retrieved
    obj = klass.from_objects(model: model)
    assert_equal [1, 2, 3], obj.items
  end

  test "composition property raises when the model does not respond to the property" do
    model = Struct.new(:other).new("value")

    klass = Class.new(Minitwin) do
      property :name, on: :model
    end

    obj = klass.from_objects(model: model)
    error = assert_raises(RuntimeError) do
      obj.name
    end
    assert_match(/does not respond to/, error.message)
  end

  test "composition with a missing model raises an unknown composition source error from from_objects" do
    klass = Class.new(Minitwin) do
      property :name, on: :missing
    end

    obj = klass.new
    error = assert_raises(RuntimeError) do
      obj.name
    end
    assert_match(/unknown composition source/, error.message)
  end

  test "composition getter returns the default and the type default when the raw value is nil" do
    model = Struct.new(:name, :age).new(nil, nil)
    twin = Class.new(Minitwin) do
      property :name, on: :model, default: "x"
      property :age, on: :model, type: Types::Integer
    end.from_object(model)
    assert_equal "x", twin.name
    assert_equal 0, twin.age
  end


  # Simulate ActiveRecord behaviour
  class RelationItem
    include ActiveModel::Model

    attr_accessor :sub
  end

  class RelationProxy
    include Enumerable

    def initialize(items)
      @items = Array(items)
    end

    def each(&blk)
      @items.each(&blk)
    end

    def to_a
      @items.dup
    end
  end

  class ContractWithRelation
    include ActiveModel::Model

    attr_accessor :items

    def initialize(items: [])
      super(items: RelationProxy.new(items))
    end
  end
end
