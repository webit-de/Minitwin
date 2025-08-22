require "test_helper"
require "mini_twin"

class ValidationTwin < MiniTwin
  property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
  property :validated_property, validates: { presence: true }
  property :duplo do
    property :brick, validates: { presence: true }
  end
  collection :cool_stuff do
    property :property, validates: { presence: true }
  end
end

class ValidationTest < ActiveSupport::TestCase
  should "validate nested properties" do
    obj = ValidationTwin.new(wrong_runtime: 123)
    assert_not obj.valid?
    assert_equal [ :validated_property, :"duplo.brick" ], obj.errors.messages.keys
    obj.validated_property = "is_set"
    assert_not obj.duplo.valid?
    assert_not obj.valid?
    assert_equal [ :"duplo.brick" ], obj.errors.messages.keys
    obj.duplo.brick = "ok"
    assert obj.valid?
  end

  should "validate collections" do
    obj = ValidationTwin.new(validated_property: 123, duplo: { brick: 123 }, cool_stuff: [ { property: "valid" }, {} ])
    assert_not obj.valid?
    assert_equal [ :"cool_stuff[1].property" ], obj.errors.messages.keys
    assert obj.cool_stuff.first.valid?
    assert_not obj.cool_stuff.last.valid?
    obj.cool_stuff.last.property = "valid"
    assert obj.valid?
  end
end

