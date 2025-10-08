require "test_helper"
require "mini_twin"

class FromCollectionTwin < MiniTwin
  property :name
end

class FromCollectionTest < ActiveSupport::TestCase
  test "should build from array of hashes" do
    list = FromCollectionTwin.from_collection([{ name: "a" }, { name: "b" }])
    assert_equal ["a", "b"], list.map(&:name)
    assert list.all? { |e| e.is_a?(FromCollectionTwin) }
  end
end

