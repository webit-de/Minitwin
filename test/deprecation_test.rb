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

  test "virtual: true emits a deprecation warning mentioning expose: false" do
    captured = capture_warning do
      Class.new(Minitwin) { property :token, virtual: true }
    end
    assert_match(/virtual:.*deprecated/, captured)
    assert_match(/expose: false/, captured)
  end

  test "virtual: true behaves like expose: false (excluded from to_hash)" do
    klass = Class.new(Minitwin) do
      property :name
      property :token, virtual: true
    end
    twin = klass.new(name: "Alice", token: "secret")
    assert_equal({ name: "Alice" }.with_indifferent_access, twin.to_hash)
  end

  test "virtual: false behaves like expose: true (included in to_hash)" do
    klass = Class.new(Minitwin) { property :score, virtual: false }
    twin = klass.new(score: 99)
    assert_equal({ score: 99 }.with_indifferent_access, twin.to_hash)
  end

  private

  def capture_warning(&block)
    original = Warning.method(:warn)
    captured = +""
    Warning.singleton_class.define_method(:warn) { |msg, **| captured << msg.to_s }
    block.call
    captured
  ensure
    Warning.singleton_class.define_method(:warn, &original)
  end
end
