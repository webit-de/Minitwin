require "test_helper"
require "mini_twin"

class SyncDefaultsTest < ActiveSupport::TestCase
  Person = Struct.new(:name, :age)

  class PersonTwin < Minitwin
    property :name
    property :age
  end

  test "sync uses stored model when no argument given" do
    model = Person.new("Eve", 30)
    twin = PersonTwin.from_object(model)
    twin.assign_params(name: "Eva", age: 31)

    assert twin.sync
    assert_equal "Eva", model.name
    assert_equal 31, model.age
  end
end

