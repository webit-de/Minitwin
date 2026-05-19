require "test_helper"
require "mini_twin"

class AttrAliasTwin < Minitwin
  property :secret_value, as: :public_value, default: 10
end

class AttributesAliasTest < ActiveSupport::TestCase
  test "attributes returns original keys even when aliased" do
    t = AttrAliasTwin.new
    # The public getter is aliased
    assert_equal 10, t.public_value
    # Original getter is protected
    assert_raises(NoMethodError) { t.secret_value }

    attrs = t.attributes
    # Attributes should include the setter/base name and value
    assert_equal({ secret_value: 10 }, attrs)
  end
end

