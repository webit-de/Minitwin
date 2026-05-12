require "test_helper"

class DynamicAliasesSkipTest < ActiveSupport::TestCase
  class NoAliases < MiniTwin
    property :name
    property :age
  end

  class WithDynamicAlias < MiniTwin
    property :name, as: -> { "n_#{age}" }
    property :age
  end

  test "class without dynamic aliases reports has_dynamic_aliases? false" do
    refute NoAliases.has_dynamic_aliases?
  end

  test "class with dynamic alias reports has_dynamic_aliases? true" do
    assert WithDynamicAlias.has_dynamic_aliases?
  end

  test "no-alias twin setters do not invoke recompute" do
    twin = NoAliases.new(name: "a", age: 1)
    called = 0
    twin.define_singleton_method(:__recompute_dynamic_aliases__) { called += 1 }
    twin.name = "b"
    twin.age = 2
    assert_equal 0, called
  end
end
