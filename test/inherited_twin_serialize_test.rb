require "test_helper"

class InheritedTwinSerializeTest < ActiveSupport::TestCase
  class Parent < Minitwin
    property :name
  end

  class Child < Parent
    property :age
  end

  test "child twin serializes inherited property" do
    c = Child.new(name: "x", age: 1)
    h = c.to_hash
    assert_equal "x", h[:name]
    assert_equal 1, h[:age]
  end

  test "child twin attributes include inherited property" do
    c = Child.new(name: "y", age: 2)
    assert_equal({ name: "y", age: 2 }, c.attributes.slice(:name, :age))
  end
end
