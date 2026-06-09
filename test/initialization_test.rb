# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class InitSubTwin < Minitwin
  property :sub_property
  property :another_sub_property, default: "default"
end

class InitTestTwin < Minitwin
  property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0, validates: { presence: true }

  property :wrong_lego, as: :lego do
    property :brick, default: 0
    property :brick_two, default: 3456
    property :brick_wrong, as: :brick_right
  end

  property :unexposed_prop, expose: false
  property :duplo do
    property :brick, validates: { presence: true }
  end

  property :an_array
  collection :empty_array

  collection :cool_stuff, as: :list_of_stuff do
    property :property, as: :renamed_property, validates: { presence: true }
    property :second_property, default: "default"
    property :block_in_collection do
      property :i_cant_believe_it, type: Types::Params::Integer.lax
      property :bool, type: Types::Params::Bool.lax
    end
  end

  property :bool, type: Types::Params::Bool.lax
end

class InitializationTest < ActiveSupport::TestCase
  test "should successfully create with coercions and defaults" do
    obj = InitTestTwin.from_hash(
      wrong_runtime: "3",
      wrong_lego: { brick: 123, brick_wrong: "wrong" },
      duplo: { brick: "big_block" },
      unexposed_prop: "ignore me",
      cool_stuff: [
        { property: "test", block_in_collection: { i_cant_believe_it: "2", bool: "1" } },
        { property: "test_2", block_in_collection: { i_cant_believe_it: "4", bool: "false" } }
      ],
      an_array: [1, 2, 3],
      bool: "0"
    )

    assert_equal 3, obj.runtime
    assert_equal 123, obj.lego.brick
    assert_equal 3456, obj.lego.brick_two
    assert_equal "ignore me", obj.unexposed_prop
    assert_equal "big_block", obj.duplo.brick
    assert_equal "wrong", obj.lego.brick_right
    assert_equal 2, obj.list_of_stuff.size
    assert_equal "test", obj.list_of_stuff.first.renamed_property
    assert_equal "default", obj.list_of_stuff.first.second_property
    assert_equal 2, obj.list_of_stuff.first.block_in_collection.i_cant_believe_it
    assert_equal 4, obj.list_of_stuff.second.block_in_collection.i_cant_believe_it
    assert obj.list_of_stuff.first.block_in_collection.bool
    assert_respond_to obj, :cool_stuff_attributes=
    assert_equal [], obj.empty_array
    refute obj.bool

    obj.cool_stuff_attributes = {}
    assert_equal 0, obj.list_of_stuff.size
  end
end
