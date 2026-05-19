require "test_helper"
require "mini_twin"

class GetterSetterTwin < Minitwin
  property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
  property :runtime_greater_than_3, getter: -> { runtime > 3 }
  property :set_days_with_variable_offset, setter: ->(value) { value.days.from_now.to_date }
end

class GetterSetterTest < ActiveSupport::TestCase
  test "should compute getter on instance" do
    a = GetterSetterTwin.from_hash(wrong_runtime: 3)
    b = GetterSetterTwin.from_hash(wrong_runtime: 4)
    assert_not a.runtime_greater_than_3
    assert b.runtime_greater_than_3
  end

  test "should apply setter on instance" do
    a = GetterSetterTwin.new(set_days_with_variable_offset: 1)
    b = GetterSetterTwin.new(set_days_with_variable_offset: 2)
    assert_equal Date.tomorrow, a.set_days_with_variable_offset
    assert_equal 2.days.from_now.to_date, b.set_days_with_variable_offset
  end
end

