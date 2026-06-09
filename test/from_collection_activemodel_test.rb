# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class AMItem
  include ActiveModel::Model

  attr_accessor :sub_property, :another_sub_property
end

class AMContract
  include ActiveModel::Model

  attr_accessor :property, :with_collection
end

class SubTwinFromCollection < Minitwin
  property :property
  collection :with_collection do
    property :sub_property, as: :renamed
    property :another_sub_property
  end
end

class FromCollectionActiveModelTest < ActiveSupport::TestCase
  test "from_collection instantiates ActiveModel items inside collections" do
    contract = AMContract.new(
      property: "alpha",
      with_collection: [
        AMItem.new(sub_property: "x", another_sub_property: "y"),
        AMItem.new(sub_property: "u", another_sub_property: "v")
      ]
    )

    list = SubTwinFromCollection.from_collection([contract])
    assert_equal 1, list.size
    twin = list.first
    assert_equal "alpha", twin.property

    # Ensure collection items are instantiated as element twins and aliases work
    assert_equal 2, twin.with_collection.size
    first = twin.with_collection.first
    second = twin.with_collection.last
    assert_kind_of Minitwin, first
    assert_equal "x", first.renamed
    assert_equal "y", first.another_sub_property
    assert_equal "u", second.renamed
    assert_equal "v", second.another_sub_property
  end
end
