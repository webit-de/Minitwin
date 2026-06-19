# frozen_string_literal: true

require "test_helper"
require "minitwin"

class DslValidationTest < ActiveSupport::TestCase

  class ValidationTwin < Minitwin
    property :wrong_runtime, as: :runtime, type: Types::Params::Integer.lax, default: 0
    property :validated_property, validates: { presence: true }
    property :duplo do
      property :brick, validates: { presence: true }
    end
    collection :cool_stuff do
      property :property, validates: { presence: true }
    end
    property(
      :validate_setter,
      setter: ->(value) { value * 2 },
      validates: lambda(&:positive?),
      type: Types::Params::Integer.lax,
      default: 1
    )
  end

  test "validates: on a nested property propagates errors to the parent" do
    obj = ValidationTwin.new(wrong_runtime: 123)
    assert_not obj.valid?
    assert_equal %i[validated_property duplo.brick], obj.errors.messages.keys
    obj.validated_property = "is_set"
    assert_not obj.duplo.valid?
    assert_not obj.valid?
    assert_equal [:"duplo.brick"], obj.errors.messages.keys
    obj.duplo.brick = "ok"
    assert_predicate obj, :valid?
  end

  test "validates: on a collection property reports the offending element index" do
    obj = ValidationTwin.new(validated_property: 123, duplo: { brick: 123 }, cool_stuff: [{ property: "valid" }, {}])
    assert_not obj.valid?
    assert_equal [:"cool_stuff[1].property"], obj.errors.messages.keys
    assert_predicate obj.cool_stuff.first, :valid?
    assert_not obj.cool_stuff.last.valid?
    obj.cool_stuff.last.property = "valid"
    assert_predicate obj, :valid?
  end

  test "validates: on a setter property validates the coerced value" do
    obj = ValidationTwin.new(wrong_runtime: 123, validated_property: "test", duplo: { brick: 124 }, validate_setter: -1)
    assert_not obj.valid?
    obj.validate_setter = 1
    assert_predicate obj, :valid?
  end

  test "adding validations without ActiveModel raises that activemodel is not available" do
    # Create a twin class without ActiveModel
    base = Class.new do
      extend Minitwin::ClassMethods

      def self.name
        "ValidationWithoutActiveModelTwin"
      end
    end

    # Should raise when trying to add validations without ActiveModel
    error = assert_raises(RuntimeError) do
      base.class_eval do
        property :name, validates: { presence: true }
      end
    end
    assert_match(/activemodel is not available/, error.message)
  end

  test "valid? returns true for a property without defined validations" do
    # When valid? is called on a twin without nested properties
    klass = Class.new(Minitwin) do
      property :name
    end

    obj = klass.new(name: "test")
    # Should be valid when no validations are defined
    assert_predicate obj, :valid?
  end
end
