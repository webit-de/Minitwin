# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class DslAliasesTest < ActiveSupport::TestCase
  class AliasTwin < Minitwin
    property :secret_value, as: :public_value, default: 10
  end

  test "protects original name when aliased" do
    t = AliasTwin.new
    assert_equal 10, t.public_value
    assert_raises(NoMethodError) { t.secret_value }
  end
end
