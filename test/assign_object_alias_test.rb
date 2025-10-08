require "test_helper"
require "mini_twin"

class AssignAliasTwin < MiniTwin
  property :sub_property, as: :renamed
  property :another_sub_property, default: "default"
end

class AssignAliasWithCollectionTwin < MiniTwin
  collection :items do
    property :sub_property, as: :renamed
    property :another_sub_property
  end
end

class AssignObjectAliasTest < ActiveSupport::TestCase
  test "assign_object copies attributes for aliased property" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "x", another_sub_property: "y")
    twin = AssignAliasTwin.new
    twin.assign_object(model)

    assert_equal "x", twin.renamed
    assert_equal "y", twin.another_sub_property
  end

  test "assign_object wraps collection elements so aliases work" do
    item = Data.define(:sub_property, :another_sub_property)
    model = Data.define(:items).new(items: [ item.new(sub_property: "a", another_sub_property: "b") ])

    twin = AssignAliasWithCollectionTwin.new
    twin.assign_object(model)

    assert_equal 1, twin.items.size
    first = twin.items.first
    assert_respond_to first, :renamed
    assert_equal "a", first.renamed
    assert_equal "b", first.another_sub_property
  end
end

