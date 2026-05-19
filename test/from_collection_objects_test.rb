require "test_helper"
require "mini_twin"

class AliasModel2
  def initialize(attrs)
    @attrs = attrs
  end

  def attributes
    @attrs
  end

  def attribute_aliases
    { alias_name: :real_name }
  end

  def real_name
    @attrs[:real_name]
  end
end

class FromCollectionAliasTwin < Minitwin
  property :alias_name
end

class FromCollectionObjectsTest < ActiveSupport::TestCase
  test "should build from array of objects with attributes and aliases" do
    models = [AliasModel2.new({ real_name: "A" }), AliasModel2.new({ real_name: "B" })]
    list = FromCollectionAliasTwin.from_collection(models)
    assert_equal ["A", "B"], list.map(&:alias_name)
    assert list.all? { |e| e.is_a?(FromCollectionAliasTwin) }
  end
end

