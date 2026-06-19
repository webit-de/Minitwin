# frozen_string_literal: true

require "test_helper"

class DeprecationTest < ActiveSupport::TestCase
  test "MiniTwin is an alias for Minitwin" do
    # Resolve MiniTwin through const_get to suppress the access warning here.
    legacy = Object.const_get(:MiniTwin)
    assert_same Minitwin, legacy
  end

  test "referencing MiniTwin emits a deprecation warning" do
    captured = capture_warning { Object.const_get(:MiniTwin) }
    assert_match(/MiniTwin.*deprecated/, captured)
  end

  private

  def capture_warning(&block)
    original = Warning.method(:warn)
    captured = +""
    Warning.singleton_class.define_method(:warn) { |msg, **| captured << msg.to_s }
    yield
    captured
  ensure
    Warning.singleton_class.define_method(:warn, &original)
  end
end
