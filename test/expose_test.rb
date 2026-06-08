require "test_helper"
require "mini_twin"

class ExposeTest < ActiveSupport::TestCase

  test "expose: false excludes property from to_hash" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :token, expose: false
    end
    twin = twin_class.new(name: "Alice", token: "secret")
    assert_equal({ name: "Alice" }.with_indifferent_access, twin.to_hash)
  end

  test "expose: true (default) includes property in to_hash" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :score, expose: true
    end
    twin = twin_class.new(name: "Bob", score: 42)
    assert_equal({ name: "Bob", score: 42 }.with_indifferent_access, twin.to_hash)
  end

  test "expose: false property is still readable via getter" do
    twin_class = Class.new(Minitwin) do
      property :token, expose: false
    end
    twin = twin_class.new(token: "abc")
    assert_equal "abc", twin.token
  end

  test "unexposed_properties lists properties with expose: false" do
    twin_class = Class.new(Minitwin) do
      property :name
      property :token, expose: false
    end
    assert_includes twin_class.unexposed_properties, :token
    refute_includes twin_class.unexposed_properties, :name
  end

  test "properties metadata stores expose: key" do
    twin_class = Class.new(Minitwin) do
      property :token, expose: false
    end
    assert_equal false, twin_class.properties[:token][:expose]
  end
end
