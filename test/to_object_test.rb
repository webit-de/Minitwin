# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class ToObjectTest < ActiveSupport::TestCase
  Person = Struct.new(:name, :age)

  class PersonTwin < Minitwin
    property :name
    property :age
  end

  test "to_object mirrors values from model to twin setters" do
    model = Person.new("Alice", 30)
    twin = PersonTwin.new(name: "Bob", age: 20)

    twin.to_object(model)

    assert_equal "Alice", twin.name
    assert_equal 30, twin.age
  end
end
