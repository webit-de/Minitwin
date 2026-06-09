# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class AliasTwin < Minitwin
  property :secret_value, as: :public_value, default: 10
end

class AliasProtectionTest < ActiveSupport::TestCase
  test "should protect original name when aliased" do
    t = AliasTwin.new
    assert_equal 10, t.public_value
    assert_raises(NoMethodError) { t.secret_value }
  end
end

class AliasProtectionExtendedTest < ActiveSupport::TestCase
  test "binding cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :binding }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end

  test "to_proc cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :to_proc }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end

  test "freeze cannot be used as dynamic alias" do
    klass = Class.new(Minitwin) do
      property :x, as: -> { :freeze }
    end
    assert_raises(ArgumentError) { klass.new(x: 1) }
  end
end
