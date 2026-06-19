# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class RbsTest < ActiveSupport::TestCase
  class RbsInnerTwin < Minitwin
    property :x, type: Types::Params::Integer.lax
  end

  # --- simple / nested / collection / aliased / empty structure ---

  test "generates RBS for a simple twin with initializer parameters" do
    klass = Class.new(Minitwin) do
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

  test "generates RBS for nested block properties" do
    klass = Class.new(Minitwin) do
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

  test "generates RBS for collections as Array initializer parameters" do
    klass = Class.new(Minitwin) do
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

  test "renders a collection with an explicit element twin as a typed Array" do
    klass = Class.new(Minitwin) do
      def self.name
        "ExplicitCollectionTwin"
      end

      collection :items, twin: RbsInnerTwin
    end

    rbs = klass.to_rbs
    assert_includes rbs, "attr_accessor items: ::Array[::#{RbsInnerTwin.name}]"
  end

  test "renders nested block property under a constantized nested class name" do
    klass = Class.new(Minitwin) do
      def self.name
        "NestedConstantTwin"
      end

      property :profile do
        property :bio
      end
    end

    rbs = klass.to_rbs
    assert defined?(klass::Profile), "Expected nested class constant Profile to be defined"
    assert_includes rbs, "attr_reader profile:"
  end

  test "renders aliased property under its original name in the initializer" do
    klass = Class.new(Minitwin) do
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

  test "generates an argument-only initializer for a twin without properties" do
    klass = Class.new(Minitwin) do
      def self.name
        "EmptyTwin"
      end
    end

    rbs = klass.to_rbs
    assert_includes rbs, "EmptyTwin"
    assert_includes rbs, "def initialize: (**untyped) -> void"
  end

  # --- type mapping ---

  test "maps dry-types to RBS scalar types" do
    klass = Class.new(Minitwin) do
      def self.name
        "TypedTwin"
      end

      property :name, type: Types::String
      property :age, type: Types::Integer
      property :active, type: Types::Bool
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

  test "maps boolean primitive to bool and unknown dry-type to untyped fallback" do
    bool_klass = Class.new(Minitwin) do
      def self.name
        "BoolPrimTwin"
      end
      property :flag, type: Types::Bool
    end
    rbs1 = bool_klass.to_rbs
    assert_includes rbs1, "flag: bool"

    dummy_t = Class.new do
      def primitive
        :weird
      end

      def to_s
        "Mystery"
      end

      def inspect
        "Mystery"
      end

      def class
        Struct
      end
    end.new
    untyped_klass = Class.new(Minitwin) do
      def self.name
        "UntypedPrimTwin"
      end
      property :myst, type: dummy_t
    end
    rbs2 = untyped_klass.to_rbs
    assert_includes rbs2, "myst: untyped"
  end

  test "maps unknown type and elementless collection to untyped" do
    dummy_t = Class.new do
      def to_s
        "Mystery"
      end

      def inspect
        "Mystery"
      end

      def class
        Struct
      end

      def call(_)
        raise "nope"
      end
    end.new

    klass = Class.new(Minitwin) do
      def self.name
        "UntypedTwin"
      end
      property :myst, type: dummy_t
      collection :stuff
    end
    rbs = klass.to_rbs
    assert_includes rbs, "myst: untyped"
    assert_includes rbs, "attr_accessor stuff: ::Array[untyped]"
  end

  # --- golden snapshot (exact format guard) ---

  test "renders complete RBS for a complex twin in the expected format" do
    klass = Class.new(Minitwin) do
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
    assert_equal "class ::UserTwin < ::Minitwin", rbs_lines[0]
    assert_equal "  attr_reader name: ::String", rbs_lines[1]
    assert_equal "  attr_writer name: ::String", rbs_lines[2]
    assert_equal "  attr_reader age: ::Integer", rbs_lines[3]
    assert_equal "  attr_writer age: ::Integer", rbs_lines[4]
    assert_equal "  attr_reader email: ::String", rbs_lines[5]
    assert_equal "  attr_writer email: ::String", rbs_lines[6]
    assert_match(/^  attr_reader profile: ::#<Class:0x.*?>::Profile$/, rbs_lines[7])
    assert_match(/^  attr_writer profile: ::#<Class:0x.*?>::Profile$/, rbs_lines[8])
    assert_match(/^  attr_accessor tags: ::Array\[::#<Class:0x.*?>::Tags\]$/, rbs_lines[9])
    assert_match(
      /^  def initialize: \(\?name: ::String, \?age: ::Integer, \?email: ::String, \?profile: ::#<Class:0x.*?>::Profile, \?tags: ::Array\[::#<Class:0x.*?>::Tags\], \*\*untyped\) -> void$/, # rubocop: disable Layout/LineLength
      rbs_lines[11]
    )
    assert_equal "end", rbs_lines[12]
  end
end
