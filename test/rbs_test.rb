require "test_helper"
require "mini_twin"

class RbsInnerTwin < Minitwin
  property :x, type: Types::Params::Integer.lax
end

class RbsTwin < Minitwin
  property :id, type: Types::Params::Integer.lax
  property :enabled, type: Types::Params::Bool.lax
  property :name
  property :profile do
    property :bio
  end

  collection :items, twin: RbsInnerTwin
end

class RbsTest < ActiveSupport::TestCase
  test "rbs_type_for covers nested and untyped branches" do
    klass = Class.new(Minitwin) do
      def self.name; "RbsBranchTwin"; end
      property :simple
      property :nested do
        property :sub
      end
      collection :items do
        property :val
      end
    end
    rbs = klass.to_rbs
    assert_includes rbs, "attr_reader nested:"
    assert_includes rbs, "attr_accessor items: ::Array"
  end

  test "should generate RBS signatures with types and nested classes" do
    rbs = RbsTwin.to_rbs

    assert_includes rbs, "class ::RbsTwin"
    assert_includes rbs, "attr_reader id: ::Integer"
    assert_includes rbs, "attr_writer id: ::Integer"
    assert_includes rbs, "attr_reader enabled: bool"
    assert_includes rbs, "attr_reader name: untyped"

    # Nested block property gets a constantized class name for RBS
    assert defined?(RbsTwin::Profile), "Expected nested class constant RbsTwin::Profile to be defined"
    assert_includes rbs, "attr_reader profile: ::RbsTwin::Profile"

    # Collections render as Array[element]
    assert_includes rbs, "attr_accessor items: ::Array[::RbsInnerTwin]"
  end
end
