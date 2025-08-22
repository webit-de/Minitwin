require "test_helper"
require "mini_twin"

class AliasTwin < MiniTwin
  property :secret_value, as: :public_value, default: 10
end

class AliasProtectionTest < ActiveSupport::TestCase
  should "protect original name when aliased" do
    t = AliasTwin.new
    assert_equal 10, t.public_value
    assert_raises(NoMethodError) { t.secret_value }
  end
end

