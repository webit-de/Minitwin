# frozen_string_literal: true

require "English"
require "test_helper"
require "minitwin"

class MinitwinTest < ActiveSupport::TestCase
  class NamedTwin < Minitwin
    property :a
  end

  # --- VERSION and DSL ---

  test "exposes VERSION and DSL" do
    assert Minitwin::VERSION

    klass = Class.new(Minitwin) do
      property :id
      collection :items do
        property :name
      end
    end

    obj = klass.new(id: 1, items: [{ name: "a" }])
    assert_equal 1, obj.id
    assert_equal "a", obj.items.first.name
  end

  # --- Descendants WeakMap ---

  test "descendants registry is a WeakMap (no strong refs)" do
    map = Minitwin.instance_variable_get(:@__descendants_map__)
    assert_kind_of ObjectSpace::WeakMap, map
  end

  test "subclasses are registered in the descendants registry" do
    klass = Class.new(Minitwin) { property :x }
    assert_includes Minitwin.__descendants__, klass
  end

  test "named subclasses remain in descendants" do
    GC.start
    assert_includes Minitwin.__descendants__, NamedTwin
  end

  test "inherited hook tracks descendants of Minitwin subclasses" do
    # Create a direct subclass of Minitwin
    parent_klass = Class.new(Minitwin) do
      property :id
    end

    # Create a subclass of the subclass (not directly from Minitwin)
    child_klass = Class.new(parent_klass) do
      property :name
    end

    # Both should be tracked in Minitwin.__descendants__
    assert_includes(
      Minitwin.__descendants__,
      parent_klass,
      "Direct Minitwin subclass should be tracked"
    )
    assert_includes(
      Minitwin.__descendants__,
      child_klass,
      "Subclass of Minitwin subclass should also be tracked in Minitwin.__descendants__"
    )
  end

  # --- ActiveModel-optional initialization ---

  test "twin initializes without ActiveModel loaded" do
    lib_path = File.expand_path("../lib", __dir__)
    script = <<~RUBY
      $LOAD_PATH.unshift(#{lib_path.inspect})

      # Stub require to skip active_model so Minitwin loads without it.
      module Kernel
        alias_method :__orig_require__, :require
        def require(path)
          return false if path == "active_model"
          __orig_require__(path)
        end
      end

      require "minitwin"
      raise "ActiveModel leaked" if defined?(ActiveModel::Model)

      class WidgetTwin < Minitwin
        property :name
      end

      twin = WidgetTwin.new(name: "ok")
      puts twin.name
    RUBY

    out = IO.popen([RbConfig.ruby, "-e", script], err: %i[child out], &:read)
    assert_equal 0, $CHILD_STATUS.exitstatus, "child failed: #{out}"
    assert_match(/^ok$/, out)
  end
end
