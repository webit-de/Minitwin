require "test_helper"
require "mini_twin"
require "pp"
require "stringio"

class SerTestTwin < Minitwin
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
  test "should convert to hash with indifferent access and omit virtuals" do
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

  test "pretty_print should format output nicely" do
    obj = SerTestTwin.from_hash(
      wrong_runtime: "42",
      wrong_lego: { brick: 100 },
      cool_stuff: [ { property: "item1" }, { property: "item2" } ],
      an_array: [1, 2, 3],
      sub_twin: { sub_property: "nested" }
    )

    # Capture pretty_print output
    output = StringIO.new
    PP.pp(obj, output)
    result = output.string

    # Verify output contains the class name and key attributes
    assert_includes result, "SerTestTwin"
    assert_includes result, "runtime"
    assert_includes result, "42"
    assert_includes result, "lego"
    assert_includes result, "brick"
  end

  test "pretty_print should handle nested objects" do
    obj = SerTestTwin.from_hash(
      sub_twin: { sub_property: "deep nested value" }
    )

    output = StringIO.new
    PP.pp(obj, output)
    result = output.string

    assert_includes result, "sub_twin"
    assert_includes result, "sub_property"
    assert_includes result, "deep nested value"
  end

  test "pretty_print should handle collections" do
    obj = SerTestTwin.from_hash(
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
end

