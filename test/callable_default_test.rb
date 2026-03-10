require "test_helper"
require "mini_twin"

class CallableDefaultTwin < MiniTwin
  property :created_at, default: -> { Time.now }
  property :static_value, default: "hello"
end

class CallableDefaultTest < ActiveSupport::TestCase
  test "callable default is evaluated on each access, not once at definition time" do
    twin1 = CallableDefaultTwin.new
    time1 = twin1.created_at

    sleep 0.01

    twin2 = CallableDefaultTwin.new
    time2 = twin2.created_at

    assert_instance_of Time, time1
    assert_instance_of Time, time2
    refute_equal time1, time2, "Expected different times but got the same — default was evaluated only once"
  end

  test "static defaults still work normally" do
    twin = CallableDefaultTwin.new
    assert_equal "hello", twin.static_value
  end

  test "callable default is not returned when value is explicitly set" do
    twin = CallableDefaultTwin.from_hash(created_at: Time.new(2020, 1, 1))
    assert_equal Time.new(2020, 1, 1), twin.created_at
  end
end
