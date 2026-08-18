# frozen_string_literal: true

require "test_helper"
require "minitwin"

class DslVisibilityTest < ActiveSupport::TestCase
  class VisibilityTwin < Minitwin
    property :name
    collection :friends
    nested :address do
      property :city
    end
  end

  DSL_METHODS = %i[property collection nested].freeze

  test "the DSL is usable from a class body" do
    twin = VisibilityTwin.new(name: "Ada")

    assert_equal "Ada", twin.name
    assert_empty twin.friends
    assert_respond_to twin, :address
  end

  test "the DSL methods are private, limiting them to class body usage" do
    DSL_METHODS.each do |method|
      refute_respond_to VisibilityTwin, method
      assert_includes VisibilityTwin.private_methods, method
    end
  end

  # Ruby installs a visibility stub in the module that changes an inherited
  # method's visibility. Those stubs shadow the typed originals, so the
  # visibility has to be declared in the module that defines the methods.
  test "the DSL methods are declared private where they are defined" do
    assert_empty Minitwin::ClassMethods.private_instance_methods(false)
    assert_empty Minitwin::ClassMethods.public_instance_methods(false)

    DSL_METHODS.each do |method|
      assert_includes Minitwin::ClassMethods::Dsl.private_instance_methods(false), method
    end
  end
end
