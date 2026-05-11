require "test_helper"
require "mini_twin"

class AssignSubTwin < MiniTwin
  property :sub_property
  property :another_sub_property, default: "default"
  property :bool?, type: Types::Params::Bool.lax
end

class AssignmentTest < ActiveSupport::TestCase
  test "should assign hash and params" do
    twin = AssignSubTwin.new
    assert_nil twin.sub_property
    assert_equal "default", twin.another_sub_property

    twin.assign_params({ sub_property: "test", "another_sub_property" => "not default" })
    assert_equal "test", twin.sub_property
    assert_equal "not default", twin.another_sub_property

    twin = AssignSubTwin.new
    twin.assign_params(ActionController::Parameters.new(sub_property: "test", another_sub_property: "not default"))
    assert_equal "test", twin.sub_property
    assert_equal "not default", twin.another_sub_property
  end

  test "assign_hash updates array element by index when not a twin/hash" do
    klass = Class.new(MiniTwin) do
      collection :items
    end
    twin = klass.new(items: [1,2,3])
    twin.assign_hash(items: [9,8,7])
    assert_equal [9,8,7], twin.items
  end

  test "should assign boolean values" do
    twin = AssignSubTwin.new(**{ "bool?" => true })
    assert_instance_of TrueClass, twin.bool?
    assert twin.bool?
    twin = AssignSubTwin.new(**{ "bool?" => false })
    assert_instance_of FalseClass, twin.bool?
    assert_not twin.bool?
  end

  test "should not assign read-only value as hash" do
    klass = Class.new(MiniTwin) do
      property :my_usual_prop
      property :my_readonly_prop, readonly: true
      property :my_nested do
        property :my_sub_readonly, readonly: true
      end
      property :my_readonly_nested, readonly: true do
        property :my_sub_prop
      end
    end

    twin =
      klass.new(
        my_usual_prop: "usual",
        my_readonly_prop: "ro",
        my_nested: { my_sub_readonly: "sub ro" },
        my_readonly_nested: { my_sub_prop: "sub prop" }
      )
    assert_equal "usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop

    twin.assign_hash(
      my_usual_prop: "new usual",
      my_readonly_prop: "new ro",
      my_nested: { my_sub_readonly: "new sub ro" },
      my_readonly_nested: { my_sub_prop: "new sub prop" }
    )
    assert_equal "new usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop
  end

  test "should not assign read-only value from object" do
    sub_model = Data.define(:my_sub_prop)
    model =
      Data.define(
        :my_usual_prop,
        :my_readonly_prop,
        :my_nested,
        :my_readonly_nested
      ).new("new usual", "new ro", sub_model.new("new sub ro"), sub_model.new("new sub prop"))

    klass = Class.new(MiniTwin) do
      property :my_usual_prop
      property :my_readonly_prop, readonly: true
      property :my_nested do
        property :my_sub_readonly, readonly: true
      end
      property :my_readonly_nested, readonly: true do
        property :my_sub_prop
      end
    end

    twin =
      klass.new(
        my_usual_prop: "usual",
        my_readonly_prop: "ro",
        my_nested: { my_sub_readonly: "sub ro" },
        my_readonly_nested: { my_sub_prop: "sub prop" }
      )
    assert_equal "usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop

    twin.assign_object(model)
    assert_equal "new usual", twin.my_usual_prop
    assert_equal "ro", twin.my_readonly_prop
    assert_equal "sub ro", twin.my_nested.my_sub_readonly
    assert_equal "sub prop", twin.my_readonly_nested.my_sub_prop
  end

end
