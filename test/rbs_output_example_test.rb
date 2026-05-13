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

    # Verify structure
    rbs_lines = rbs.split("\n")
    assert_equal rbs_lines[0], "class ::UserTwin < ::MiniTwin"
    assert_equal rbs_lines[1], "  attr_reader name: ::String"
    assert_equal rbs_lines[2], "  attr_writer name: ::String"
    assert_equal rbs_lines[3], "  attr_reader age: ::Integer"
    assert_equal rbs_lines[4], "  attr_writer age: ::Integer"
    assert_equal rbs_lines[5], "  attr_reader email: ::String"
    assert_equal rbs_lines[6], "  attr_writer email: ::String"
    assert_match(/^  attr_reader profile: ::#<Class:0x.*?>::Profile$/, rbs_lines[7])
    assert_match(/^  attr_writer profile: ::#<Class:0x.*?>::Profile$/, rbs_lines[8])
    assert_match(/^  attr_accessor tags: ::Array\[::#<Class:0x.*?>::Tags\]$/, rbs_lines[9])
    assert_match(
      /^  def initialize: \(\?name: ::String, \?age: ::Integer, \?email: ::String, \?profile: ::#<Class:0x.*?>::Profile, \?tags: ::Array\[::#<Class:0x.*?>::Tags\], \*\*untyped\) -> void$/,
      rbs_lines[11]
    )
    assert_equal rbs_lines[12], "end"
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
