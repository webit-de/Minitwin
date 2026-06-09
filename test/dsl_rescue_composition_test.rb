# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class DslRescueCompositionTest < ActiveSupport::TestCase
  test "composition getter rescues collections meta lookup errors" do
    src = Struct.new(:foo).new("value")
    klass = Class.new(Minitwin) do
      property :foo, on: :src
    end
    t = klass.from_objects(src: src)
    def klass.collections(*)
      raise "boom"
    end
    assert_equal "value", t.foo
  end
end
