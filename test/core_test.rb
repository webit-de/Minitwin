require "test_helper"
require "mini_twin"

class MiniTwinCoreTest < ActiveSupport::TestCase
  should "expose VERSION and DSL" do
    assert MiniTwin::VERSION

    klass = Class.new(MiniTwin) do
      property :id
      collection :items do
        property :name
      end
    end

    obj = klass.new(id: 1, items: [{ name: "a" }])
    assert_equal 1, obj.id
    assert_equal "a", obj.items.first.name
  end
end

