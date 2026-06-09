# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class FromCollectionTwin < Minitwin
  property :name
end

class FromCollectionTest < ActiveSupport::TestCase
  test "should build from array of hashes" do
    list = FromCollectionTwin.from_collection([{ name: "a" }, { name: "b" }])
    assert_equal %w[a b], list.map(&:name)
    assert(list.all?(FromCollectionTwin))
  end
end
