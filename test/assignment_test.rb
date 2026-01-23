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

end
