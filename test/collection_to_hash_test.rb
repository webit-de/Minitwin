require "test_helper"
require "mini_twin"

class CollectionTwin < MiniTwin
  collection :values
end

class ValueTwin < MiniTwin
  property :my_value
end

class CollectionToHashTest < ActiveSupport::TestCase
  test "collection to hash contains values" do
    collection_twin = CollectionTwin.new
    value_twins = [ ValueTwin.new(my_value: "foo") ]
    collection_twin.values = value_twins
    h = collection_twin.to_hash
    assert_equal "foo", h[:values].first[:my_value]
  end
end
