require "test_helper"
require "mini_twin"

class FakeManagedServiceCategory2
  def initialize(value:)
    @value = value
  end

  def attributes
    { value: @value }
  end

  def value
    @value
  end
end

class FakeContract2
  def initialize(id:, managed_service_category: nil)
    @id = id
    @msc = managed_service_category
  end

  def attributes
    { id: @id, managed_service_category: nil }
  end

  def managed_service_category
    @msc
  end
end

class ManagedServiceTwinCollection < Minitwin
  property :id
  property :managed_service_category do
    property :value, as: :category
  end
end

class FromCollectionNilAttributeEnrichmentTest < ActiveSupport::TestCase
  test "from_collection uses has_one reader when attributes key is nil" do
    items = [
      FakeContract2.new(id: 1, managed_service_category: FakeManagedServiceCategory2.new(value: "A")),
      FakeContract2.new(id: 2, managed_service_category: FakeManagedServiceCategory2.new(value: "B"))
    ]

    list = ManagedServiceTwinCollection.from_collection(items)
    assert_equal 2, list.size
    assert_equal [1, 2], list.map(&:id)
    assert list.all? { |e| !e.managed_service_category.nil? }
    assert_equal ["A", "B"], list.map { |e| e.managed_service_category.category }
  end
end

