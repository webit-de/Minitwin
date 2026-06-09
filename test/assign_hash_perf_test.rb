# frozen_string_literal: true

require "test_helper"

class AssignHashPerfTest < ActiveSupport::TestCase
  class T < Minitwin
    property :name, as: -> { "n_#{name}" }
    property :age
    property :email
  end

  test "assign_hash recomputes aliases at most once per call" do
    t = T.new(name: "a", age: 1, email: "x@y")
    calls = 0
    t.define_singleton_method(:__recompute_dynamic_aliases__) { calls += 1 }
    t.assign_hash(name: "b", age: 2, email: "z@y")
    assert_operator calls, :<=, 1
  end

  test "assign_hash with one key only writes that one attribute" do
    t = T.new(name: "orig_name", age: 7, email: "orig@x")
    t.assign_hash(name: "new_name")
    assert_equal "new_name", t.send(:name)
    assert_equal 7, t.age
    assert_equal "orig@x", t.email
  end

  test "assign_hash ignores unknown keys without error" do
    t = T.new(name: "a")
    t.assign_hash(name: "b", bogus: 1, other_bogus: 2)
    assert_equal "b", t.send(:name)
  end
end
