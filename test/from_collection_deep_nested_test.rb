require "test_helper"
require "mini_twin"

# Source models simulating plain Ruby/ActiveModel-like objects
class Subcategory
  include ActiveModel::Model
  attr_accessor :code
end

class Category
  include ActiveModel::Model
  attr_accessor :name, :subcategories, :info, :tag

  # Simulate has_one-like overshadowing in attributes by returning nil for :info
  def attributes
    { name: @name, subcategories: @subcategories, info: nil, tag: @tag }
  end
end

class CategoryInfo
  include ActiveModel::Model
  attr_accessor :label
end

class ManagedService
  include ActiveModel::Model
  attr_accessor :title, :categories
end

class ContractDeep
  include ActiveModel::Model
  attr_accessor :id, :managed_service
end

# Deeply nested twin with a block property containing a collection, which
# itself contains a further nested collection.
class DeepCollectionTwin < Minitwin
  property :id
  property :managed_service do
    property :title
    collection :categories do
      property :name
      # Add a block property inside each category element
      property :info do
        property :label
      end
      # Add a nested group inside the category element; inner leaf is set via
      # element-level setter `tag=` on the twin which writes under `extra`.
      nested :extra do
        property :tag
      end
      collection :subcategories do
        property :code
      end
    end
  end
end

class FromCollectionDeepNestedTest < ActiveSupport::TestCase
  test "from_collection builds deep nested block + collections" do
    items = [
      ContractDeep.new(
        id: 1,
        managed_service: ManagedService.new(
          title: "MS-A",
          categories: [
            Category.new(name: "C1", info: CategoryInfo.new(label: "I1"), tag: "T1", subcategories: [Subcategory.new(code: "s1"), Subcategory.new(code: "s2")]),
            Category.new(name: "C2", info: CategoryInfo.new(label: "I2"), tag: "T2", subcategories: [Subcategory.new(code: "s3")])
          ]
        )
      ),
      ContractDeep.new(
        id: 2,
        managed_service: ManagedService.new(
          title: "MS-B",
          categories: [
            Category.new(name: "C3", info: CategoryInfo.new(label: "I3"), tag: "T3", subcategories: [])
          ]
        )
      )
    ]

    list = DeepCollectionTwin.from_collection(items)
    assert_equal 2, list.size

    first = list.first
    assert_equal 1, first.id
    assert_equal "MS-A", first.managed_service.title
    assert_equal 2, first.managed_service.categories.size
    assert_kind_of Minitwin, first.managed_service.categories.first
    assert_equal "C1", first.managed_service.categories.first.name
    assert_equal ["s1", "s2"], first.managed_service.categories.first.subcategories.map(&:code)
    assert_equal ["I1", "I2"], first.managed_service.categories.map { |c| c.info.label }
    # Ensure nested group serializes under container key
    first_hash = first.to_hash
    assert_equal "T1", first_hash[:managed_service][:categories][0][:extra][:tag]
    assert_equal "T2", first_hash[:managed_service][:categories][1][:extra][:tag]

    second = list.last
    assert_equal 2, second.id
    assert_equal "MS-B", second.managed_service.title
    assert_equal ["C3"], second.managed_service.categories.map(&:name)
    assert_equal [[]], second.managed_service.categories.map { |c| c.subcategories.map(&:code) }
    assert_equal ["I3"], second.managed_service.categories.map { |c| c.info.label }
    second_hash = second.to_hash
    assert_equal "T3", second_hash[:managed_service][:categories][0][:extra][:tag]
  end

  # Simulate ActiveRecord's CollectionProxy via a lightweight wrapper that is
  # not an Array but responds to to_a and Enumerable.
  class RelationProxy
    include Enumerable
    def initialize(items)
      @items = Array(items)
    end
    def each(&blk)
      @items.each(&blk)
    end
    def to_a
      @items.dup
    end
    def size
      @items.size
    end
  end

  test "from_collection builds deep nested with relation proxies" do
    items = [
      ContractDeep.new(
        id: 11,
        managed_service: ManagedService.new(
          title: "MS-R1",
          categories: RelationProxy.new([
            Category.new(name: "RC1", info: CategoryInfo.new(label: "RI1"), tag: "RT1", subcategories: RelationProxy.new([Subcategory.new(code: "rs1")]))
          ])
        )
      ),
      ContractDeep.new(
        id: 22,
        managed_service: ManagedService.new(
          title: "MS-R2",
          categories: RelationProxy.new([
            Category.new(name: "RC2", info: CategoryInfo.new(label: "RI2"), tag: "RT2", subcategories: RelationProxy.new([Subcategory.new(code: "rs2"), Subcategory.new(code: "rs3")]))
          ])
        )
      )
    ]

    list = DeepCollectionTwin.from_collection(items)
    assert_equal 2, list.size

    first = list.first
    assert_equal 11, first.id
    assert_equal "MS-R1", first.managed_service.title
    assert_equal ["RC1"], first.managed_service.categories.map(&:name)
    assert_equal ["RI1"], first.managed_service.categories.map { |c| c.info.label }
    assert_equal [["rs1"]], first.managed_service.categories.map { |c| c.subcategories.map(&:code) }
    fh = first.to_hash
    assert_equal "RT1", fh[:managed_service][:categories][0][:extra][:tag]

    second = list.last
    assert_equal 22, second.id
    assert_equal "MS-R2", second.managed_service.title
    assert_equal ["RC2"], second.managed_service.categories.map(&:name)
    assert_equal ["RI2"], second.managed_service.categories.map { |c| c.info.label }
    assert_equal [["rs2", "rs3"]], second.managed_service.categories.map { |c| c.subcategories.map(&:code) }
    sh = second.to_hash
    assert_equal "RT2", sh[:managed_service][:categories][0][:extra][:tag]
  end
end
