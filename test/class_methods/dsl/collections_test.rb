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

  test "collection with an unknown option raises a Minitwin::DefinitionError" do
    error = assert_raises(Minitwin::DefinitionError) do
      Class.new(Minitwin) do
        collection :items, twni: Class.new(Minitwin)
      end
    end

    assert_equal(
      "Unknown option `twni:` for collection 'items'. Allowed options: validates, default, as, getter, twin, on.",
      error.message
    )
  end

  test "collection rejects property-only options instead of ignoring them" do
    error = assert_raises(Minitwin::DefinitionError) do
      Class.new(Minitwin) do
        collection :items, expose: false
      end
    end

    assert_match(/Unknown option `expose:` for collection 'items'/, error.message)
  end
end
