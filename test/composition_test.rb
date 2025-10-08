require "test_helper"
require "mini_twin"

class CompositionTwin < MiniTwin
  property :id, as: :customer_id, on: :customer
  property :id, as: :address_id, on: :address
  property :name, on: :customer
  property :street, on: :address
  property :latitude, on: :address, virtual: true
  property :country, default: "D"
end

class CompositionTest < ActiveSupport::TestCase
  test "should instantiate composition twins from objects" do
    customer = Data.define(:id, :name).new(id: 123, name: "Petra Rodriguez")
    address = Data.define(:id, :street, :latitude).new(id: "abc", street: "1234 fake street", latitude: 55.76)
    obj = CompositionTwin.from_objects(customer:, address:)

    assert_equal 123, obj.customer_id
    assert_equal "abc", obj.address_id
    assert_equal "Petra Rodriguez", obj.name
    assert_equal "1234 fake street", obj.street
    assert_equal "D", obj.country

    hash = obj.to_hash
    assert_equal "abc", hash[:address_id]
    assert_equal 123, hash[:customer_id]
    assert_equal "Petra Rodriguez", hash[:name]
    assert_equal "1234 fake street", hash[:street]
    assert_equal "D", hash[:country]
    assert_nil hash[:latitude]
  end
end

