# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class SyncCollectionByIdTest < ActiveSupport::TestCase
  ItemModel = Struct.new(:id, :value)
  OrderModel = Struct.new(:items)

  class OrderTwin < Minitwin
    collection :items do
      property :id
      property :value
    end
  end

  test "sync collection elements by id when possible, else by index" do
    o = OrderModel.new(
      [
        ItemModel.new(1, "a"),
        ItemModel.new(2, "b")
      ]
    )

    twin = OrderTwin.from_object(o)
    # reorder and change values
    twin.items = [
      { id: 2, value: "B2" },
      { id: 1, value: "A1" }
    ]

    assert twin.sync(nil) # use stored model

    # Expect in-place updates matched by id, not index
    assert_equal 1, o.items[0].id
    assert_equal "A1", o.items[0].value
    assert_equal 2, o.items[1].id
    assert_equal "B2", o.items[1].value
  end

  test "falls back to writer assigning array of hashes when no target collection" do
    o = OrderModel.new(nil)
    twin = OrderTwin.from_params(items: [{ id: 1, value: "x" }])

    assert twin.sync(o, validate: false)
    assert_kind_of Array, o.items
    assert_equal [{ id: 1, value: "x" }.with_indifferent_access], o.items
  end
end
