require "test_helper"
require "mini_twin"

class SerTestTwin < MiniTwin
  property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
  property :virtual_prop, virtual: true
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

class SerializationTest < ActiveSupport::TestCase
  should "convert to hash with indifferent access and omit virtuals" do
    obj = SerTestTwin.from_hash(
      wrong_runtime: "3",
      wrong_lego: { brick: 123 },
      virtual_prop: "ignore me",
      cool_stuff: [ { property: "test" } ],
      an_array: [1,2,3],
      sub_twin: {}
    )

    hash = obj.to_hash
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
    assert_nil hash["virtual_prop"]
    assert_nil hash["wrong_runtime"]
    assert_equal 3, hash["runtime"]
    assert_equal 123, hash[:lego][:brick]
    assert_equal [1,2,3], hash[:an_array]
    assert_equal [], hash[:empty_array]
    assert_not hash["sub_twin"].has_key?(:sub_property)
  end
end

