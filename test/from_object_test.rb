# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class TwinFromObject < Minitwin
  property :sub_property, as: :renamed
  property :another_sub_property, default: "default"
end

class NestedTwinFromObject < Minitwin
  property :sub_property, as: :renamed
  property :another_sub_property do
    property :name
    property :age
  end
end

class SubTwinFromObject < Minitwin
  property :property, on: :contract
  collection :with_collection, on: :contract do
    property :sub_property, as: :renamed
    property :another_sub_property
  end
end

class Person
  include ActiveModel::Model

  attr_accessor :name, :age, :sub_property, :another_sub_property
end

class FromObjectTest < ActiveSupport::TestCase
  test "should instantiate from a plain object and track model" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "test", another_sub_property: "another test")
    obj = TwinFromObject.from_object(model)
    assert_equal "test", obj.renamed
    assert_equal "another test", obj.another_sub_property

    model = Data.define(:sub_property).new(sub_property: "test2")
    obj = TwinFromObject.from_object(model)
    assert_equal model, obj.instance_variable_get("@internal_model__model")
    assert_equal "test2", obj.renamed
    assert_equal "default", obj.another_sub_property
  end

  test "should instantiate from an activemodel object" do
    model = Person.new(sub_property: "bob", another_sub_property: "18")
    obj = TwinFromObject.from_object(model)
    assert_equal "bob", obj.renamed
    assert_equal "18", obj.another_sub_property
  end

  test "should instantiate from an activemodel object in a block" do
    person = Person.new(name: "bob", age: "18")
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "test", another_sub_property: person)
    obj = NestedTwinFromObject.from_object(model)
    assert_equal "test", obj.renamed
    assert_equal "bob", obj.another_sub_property.name
  end

  test "should correctly instantiate from object with collections" do
    collection = Data.define(:sub_property, :another_sub_property)
    contract =
      Data.
        define(:property, :with_collection).
        new(
          property: "test normal",
          with_collection: [
            collection.new(sub_property: "test", another_sub_property: "another test"),
            collection.new(sub_property: "test2", another_sub_property: "test")
          ]
        )
    obj = SubTwinFromObject.from_objects(contract: contract)
    assert_equal "test normal", obj.property
    assert_instance_of Array, obj.with_collection
    assert_equal 2, obj.with_collection.size
    first_collection = obj.with_collection.first
    assert_equal "test", first_collection.renamed
    assert_equal "another test", first_collection.another_sub_property
    second_collection = obj.with_collection.second
    assert_equal "test2", second_collection.renamed
    assert_equal "test", second_collection.another_sub_property
  end
end
