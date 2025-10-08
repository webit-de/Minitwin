require "test_helper"
require "mini_twin"

class AliasModel
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

class FromObjectsAliasTwin < MiniTwin
  property :alias_name
end

class FromObjectsAttributeAliasesTest < ActiveSupport::TestCase
  test "should merge attribute_aliases into attributes" do
    model = AliasModel.new({ real_name: "Value" })
    twin = FromObjectsAliasTwin.from_object(model)
    assert_equal "Value", twin.alias_name
  end
end

