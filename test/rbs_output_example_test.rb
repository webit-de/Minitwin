require "test_helper"
require "mini_twin"

class RbsOutputExampleTest < ActiveSupport::TestCase
  test "should generate complete RBS for complex twin" do
    klass = Class.new(MiniTwin) do
      def self.name
        "UserTwin"
      end

      property :name, type: Types::String
      property :age, type: Types::Integer
      property :email, type: Types::String

      property :profile do
        property :bio, type: Types::String
        property :avatar_url, type: Types::String
      end

      collection :tags do
        property :label, type: Types::String
      end
    end

    rbs = klass.to_rbs

    # Print for manual verification during development
    puts "\n" + "="*80
    puts "Generated RBS for UserTwin:"
    puts "="*80
    puts rbs
    puts "="*80 + "\n"

    # Verify structure
    assert_includes rbs, "class ::UserTwin < ::MiniTwin"
    assert_includes rbs, "attr_reader name: ::String"
    assert_includes rbs, "attr_writer name: ::String"
    assert_includes rbs, "attr_reader age: ::Integer"
    assert_includes rbs, "attr_writer age: ::Integer"
    assert_includes rbs, "attr_reader email: ::String"
    assert_includes rbs, "attr_writer email: ::String"
    assert_includes rbs, "attr_reader profile:"
    assert_includes rbs, "attr_writer profile:"
    assert_includes rbs, "attr_accessor tags: ::Array"
    assert_includes rbs, "def initialize: (?name: ::String, ?age: ::Integer, ?email: ::String, ?profile:"
    assert_includes rbs, "?tags: ::Array"
    assert_includes rbs, "**untyped) -> void"
    assert_includes rbs, "end"
  end

  test "should generate RBS with proper formatting for multiple properties" do
    klass = Class.new(MiniTwin) do
      def self.name
        "ProductTwin"
      end

      property :id, type: Types::Integer
      property :title, type: Types::String
      property :price, type: Types::Float
      property :available, type: Types::Bool
    end

    rbs = klass.to_rbs

    # Verify all types are correctly mapped
    assert_includes rbs, "id: ::Integer"
    assert_includes rbs, "title: ::String"
    assert_includes rbs, "price: ::Float"
    assert_includes rbs, "available: bool"

    # Verify initializer has all parameters
    assert_includes rbs, "def initialize: (?id: ::Integer, ?title: ::String, ?price: ::Float, ?available: bool"
  end
end
