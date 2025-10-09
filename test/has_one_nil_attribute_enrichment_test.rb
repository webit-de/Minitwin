require "test_helper"
require "mini_twin"

# Refactored to runnable, DB-free test that simulates the issue:
# - Model.attributes contains a nil key for the association name
# - Reader method returns the associated object (as in has_one)

class FakeManagedServiceCategory
  def initialize(value:)
    @value = value
  end

  # Simulate AR exposing joined column as a regular attribute
  def attributes
    { value: @value }
  end

  def value
    @value
  end
end

class FakeContract
  def initialize(id:, managed_service_category: nil)
    @id = id
    @msc = managed_service_category
  end

  # Important: key present with nil, like an attribute overshadowing the reader
  def attributes
    { id: @id, managed_service_category: nil }
  end

  def managed_service_category
    @msc
  end
end

class ManagedServiceTwin < MiniTwin
  property :id
  property :productname, as: :product_name
  property :productno, as: :product_no

  property :managed_service_category do
    property :value, as: :category
  end
end

class HasOneNilAttributeEnrichmentTest < ActiveSupport::TestCase
  test "from_object uses has_one reader when attributes key is nil" do
    contract = FakeContract.new(id: 1, managed_service_category: FakeManagedServiceCategory.new(value: "MSP"))
    obj = ManagedServiceTwin.from_object(contract)
    # Should instantiate nested twin from reader even though attributes had the key with nil
    assert_not obj.managed_service_category.nil?
    assert_equal "MSP", obj.managed_service_category.category
  end
end

