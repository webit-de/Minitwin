# frozen_string_literal: true

require "test_helper"
require "minitwin"

class DslCollectionsTest < ActiveSupport::TestCase
  test "collection supports _attributes suffix writer and reader" do
    klass = Class.new(Minitwin) do
      collection :items do
        property :name
      end
    end

    obj = klass.new
    # Should support _attributes suffix for collections
    obj.items_attributes = [{ name: "test" }]
    assert_equal "test", obj.items.first.name
  end
end
