require "test_helper"
require "mini_twin"

class SyncObjectTest < ActiveSupport::TestCase

  test "should handle to_object method" do
    model = Struct.new(:name, :value).new("from_model", 42)

    klass = Class.new(MiniTwin) do
      property :name
      property :value
    end

    assert_equal "from_model", model.name
    assert_equal 42, model.value

    obj = klass.new(name: "original", value: 10)
    obj.sync(model)

    assert_equal "original", model.name
    assert_equal 10, model.value
  end

  class SimpleContract < MiniTwin
    property :name, validates: { presence: true }
    property :age, validates: { presence: true, numericality: { greater_than: 17 } }
  end

  test "should handle a form livecycle" do
    model = Struct.new(:name, :age).new("Max", 18)

    # presenting form
    contract = SimpleContract.from_object(model)
    assert contract.valid?
    assert_equal "Max", contract.name
    assert_equal 18, contract.age

    # submitting form
    contract = SimpleContract.from_params({ name: 'Moritz', age: 15 })
    refute contract.valid?
    assert_equal ["must be greater than 17"], contract.errors[:age]

    contract = SimpleContract.from_params({ name: 'Moritz', age: 19 })
    assert contract.valid?
    assert contract.sync(model)

    assert_equal "Moritz", model.name
    assert_equal 19, model.age
  end

  test "should sync objects even if they are not valid" do
    model = Struct.new(:name, :age).new("Max", 18)

    # presenting form
    contract = SimpleContract.from_object(model)
    assert contract.valid?
    assert_equal "Max", contract.name
    assert_equal 18, contract.age

    # submitting form
    contract = SimpleContract.from_params({ name: 'Moritz', age: 15 })
    refute contract.valid?
    assert_equal ["must be greater than 17"], contract.errors[:age]
    assert_not contract.sync(model)

    assert_equal "Max", model.name
    assert_equal 18, model.age

    assert contract.sync(model, validate: false)
    assert_equal "Moritz", model.name
    assert_equal 15, model.age
  end

end
