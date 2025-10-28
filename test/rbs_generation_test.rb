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
  end
end
