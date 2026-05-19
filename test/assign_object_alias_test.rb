require "test_helper"
require "mini_twin"

class AssignAliasTwin < Minitwin
  property :sub_property, as: :renamed
  property :another_sub_property, default: "default"
end

class AssignAliasWithCollectionTwin < Minitwin
  collection :items do
    property :sub_property, as: :renamed
    property :another_sub_property
  end
end

class AssignAliasAsLambdaTwin < Minitwin
  property :sub_property
  property :another_sub_property, as: -> { @sub_property }
end

class NestedAssignAliasAsLambdaTwin < Minitwin
  nested :some_nesting do
    property :sub_property
    property :another_sub_property, as: -> { @sub_property }
  end
end

class CollectionDynamicAliasTwin < Minitwin
  collection :items do
    property :sub_property
    property :another_sub_property, as: -> { @sub_property }
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

  test "should accept an lambda in an as attribute" do
    model = Data.define(:sub_property, :another_sub_property).new('a', 'b')
    twin = AssignAliasAsLambdaTwin.from_object(model)
    assert_equal "a", twin.sub_property
    assert_equal "b", twin.a
  end

  test "dynamic alias serializes under alias and updates on rename" do
    model = Data.define(:sub_property, :another_sub_property).new('key1', 'val1')
    twin = AssignAliasAsLambdaTwin.from_object(model)

    # Serializes using the dynamic alias as the key
    h = twin.to_hash
    assert_equal({ key1: 'val1' }.with_indifferent_access, h.slice(:key1))
    refute h.key?(:another_sub_property)

    # Change the alias target and ensure serialization reflects the new key
    twin.sub_property = 'key2'
    twin.another_sub_property = 'val2'
    h2 = twin.to_hash
    assert_equal({ key2: 'val2' }.with_indifferent_access, h2.slice(:key2))
    refute h2.key?(:key1)
  end

  test "assign_object copies attributes with nested aliased property" do
    model = Data.define(:sub_property, :another_sub_property).new(sub_property: "a", another_sub_property: "b")
    twin = NestedAssignAliasAsLambdaTwin.new
    twin.assign_object(model)

    assert_equal "a", twin.sub_property
    assert_equal "b", twin.a
    # Update via top-level nested proxies
    twin.sub_property = "x"
    twin.another_sub_property = "y"
    assert_equal({ some_nesting: { sub_property: "x", x: "y" } }.deep_stringify_keys, twin.to_hash)
  end

  test "dynamic alias works in collection elements and renames on change" do
    item_struct = Data.define(:sub_property, :another_sub_property)
    model = Data.define(:items).new(items: [ item_struct.new('k1', 'v1'), item_struct.new('k2', 'v2') ])

    twin = CollectionDynamicAliasTwin.from_object(model)
    assert_equal 2, twin.items.size

    # First element exposes alias k1 and serializes under it
    first = twin.items.first
    assert_equal 'v1', first.k1
    h = twin.to_hash
    assert_equal 'v1', h[:items][0][:k1]
    refute h[:items][0].key?(:another_sub_property)

    # Rename inside element and verify updated alias and serialization
    first.sub_property = 'k1_renamed'
    first.another_sub_property = 'v1b'
    h2 = twin.to_hash
    assert_equal 'v1b', twin.items.first.k1_renamed
    assert_equal 'v1b', h2[:items][0][:k1_renamed]
    refute h2[:items][0].key?(:k1)
  end

  class CollectionNameDynamicAliasTwin < Minitwin
    property :alias_key
    collection :items, as: -> { alias_key } do
      property :value
    end
  end

  test "dynamic alias works on collection name and updates on rename" do
    model = Data.define(:alias_key, :items).new('things', [ { value: 1 }, { value: 2 } ])
    twin = CollectionNameDynamicAliasTwin.from_hash(alias_key: model.alias_key, items: model.items)

    # Access via dynamic collection reader
    assert_respond_to twin, :things
    assert_equal [ 1, 2 ], twin.things.map(&:value)

    # Serialization uses dynamic collection name and omits base name
    h = twin.to_hash
    assert h.key?(:things)
    refute h.key?(:items)
    assert_equal [ { value: 1 }, { value: 2 } ].map(&:with_indifferent_access), h[:things]

    # Update alias key and verify rename takes effect
    twin.alias_key = 'stuff'
    h2 = twin.to_hash
    assert h2.key?(:stuff)
    refute h2.key?(:things)
    assert_equal [ 1, 2 ], twin.stuff.map(&:value)
  end

end
