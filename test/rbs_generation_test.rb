require "test_helper"
require "mini_twin"

class RbsGenerationTest < ActiveSupport::TestCase
  test "should generate RBS for simple twin" do
    klass = Class.new(MiniTwin) do
      def self.name
        "SimpleTwin"
      end

      property :name
      property :age
    end

    rbs = klass.to_rbs
    assert_includes rbs, "SimpleTwin"
    assert_includes rbs, "name:"
    assert_includes rbs, "age:"
    assert_includes rbs, "def initialize:"
    assert_includes rbs, "?name:"
    assert_includes rbs, "?age:"
  end

  test "should generate RBS for nested twins" do
    klass = Class.new(MiniTwin) do
      def self.name
        "NestedTwin"
      end

      property :profile do
        property :bio
      end
    end

    rbs = klass.to_rbs
    assert_includes rbs, "NestedTwin"
    assert_includes rbs, "profile:"
    assert_includes rbs, "def initialize:"
    assert_includes rbs, "?profile:"
  end

  test "should generate RBS for collections" do
    klass = Class.new(MiniTwin) do
      def self.name
        "CollectionTwin"
      end

      collection :items do
        property :name
      end
    end

    rbs = klass.to_rbs
    assert_includes rbs, "CollectionTwin"
    assert_includes rbs, "items:"
    assert_includes rbs, "def initialize:"
    assert_includes rbs, "?items: ::Array"
  end

  test "should handle RBS generation for twins with aliases" do
    klass = Class.new(MiniTwin) do
      def self.name
        "AliasedTwin"
      end

      property :name, as: :full_name
    end

    rbs = klass.to_rbs
    assert_includes rbs, "AliasedTwin"
    assert_includes rbs, "def initialize:"
    # Original property name should be in initializer
    assert_includes rbs, "?name:"
  end

  test "should generate RBS with typed properties" do
    klass = Class.new(MiniTwin) do
      def self.name
        "TypedTwin"
      end

      property :name, type: MiniTwin::Types::String
      property :age, type: MiniTwin::Types::Integer
      property :active, type: MiniTwin::Types::Bool
    end

    rbs = klass.to_rbs
    assert_includes rbs, "TypedTwin"
    assert_includes rbs, "name: ::String"
    assert_includes rbs, "age: ::Integer"
    assert_includes rbs, "active: bool"
    assert_includes rbs, "def initialize:"
    assert_includes rbs, "?name: ::String"
    assert_includes rbs, "?age: ::Integer"
    assert_includes rbs, "?active: bool"
  end

  test "should generate RBS for twin without properties" do
    klass = Class.new(MiniTwin) do
      def self.name
        "EmptyTwin"
      end
    end

    rbs = klass.to_rbs
    assert_includes rbs, "EmptyTwin"
    assert_includes rbs, "def initialize: (**untyped) -> void"
  end
end
