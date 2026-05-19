require "test_helper"
require "mini_twin"

class AssignNestedOuter < Minitwin
  collection :items do
    property :value
    property :nested do
      property :nval
    end
  end
end

class AssignHashNestedUpdateTest < ActiveSupport::TestCase
  test "should update nested collection items via assign_hash" do
    t = AssignNestedOuter.from_hash(items: [
      { value: 1, nested: { nval: "a" } },
      { value: 2, nested: { nval: "b" } }
    ])

    t.assign_hash(items: [{}, { nested: { nval: "Z" } }])
    assert_equal "a", t.items.first.nested.nval
    assert_equal "Z", t.items.last.nested.nval
  end
end
