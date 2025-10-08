require "test_helper"
require "mini_twin"

class AssignSubTwin < MiniTwin
  property :sub_property
  property :another_sub_property, default: "default"
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
end

