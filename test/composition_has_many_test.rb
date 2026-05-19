require "test_helper"
require "mini_twin"

class RelItem
  include ActiveModel::Model
  attr_accessor :sub
end

# Simulate ActiveRecord::Associations::CollectionProxy (not an Array)
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
end

class ContractWithRelation
  include ActiveModel::Model
  attr_accessor :items

  def initialize(items: [])
    super(items: RelationProxy.new(items))
  end
end

class ContractCompTwin < Minitwin
  collection :items, on: :contract do
    property :sub, as: :renamed
  end
end

class CompositionHasManyTest < ActiveSupport::TestCase
  test "collection on: wraps non-Array relations into element twins" do
    items = [RelItem.new(sub: "x"), RelItem.new(sub: "y")]
    contract = ContractWithRelation.new(items: items)
    twin = ContractCompTwin.from_objects(contract: contract)

    assert_equal 2, twin.items.size
    assert_kind_of Minitwin, twin.items.first
    assert_equal "x", twin.items.first.renamed
    assert_equal "y", twin.items.last.renamed
  end
end

