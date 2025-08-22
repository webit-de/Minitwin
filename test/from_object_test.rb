require "test_helper"
require "mini_twin"

class TwinFromObject < MiniTwin
  property :sub_property, as: :renamed
  property :another_sub_property, default: "default"
end

class FromObjectTest < ActiveSupport::TestCase
  should "instantiate from a plain object and track model" do
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
end

